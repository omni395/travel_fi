# frozen_string_literal: true

#
# OsmImportBroadcaster — отправляет прогресс и результаты импорта OSM через WebSocket
#
# Ответственность:
# 1. started — отправляет сигнал о старте импорта (переключение UI на спиннер)
# 2. progress — отправляет промежуточный прогресс импорта (total/processed/already_in_db)
# 3. call — отправляет финальный результат импорта + обновляет UI + триггерит перезагрузку карты
#
class OsmImportBroadcaster
  include CableReady::Broadcaster

  #
  # Отправляет сигнал о старте импорта (переключение UI на панель прогресса)
  #
  # @param user [User] админ, инициировавший импорт
  # @param category [PoiCategory] категория импорта
  #
  def self.started(user:, category:)
    new(user: user).send_started(category: category)
  end

  #
  # Отправляет промежуточный прогресс импорта
  #
  # @param user [User] админ, инициировавший импорт
  # @param total [Integer] общее количество элементов из OSM
  # @param processed [Integer] сколько обработано
  # @param already_in_db [Integer] сколько из found уже есть в БД (для первого прогресса)
  #
  def self.progress(user:, total:, processed:, already_in_db: nil)
    new(user: user).progress(total: total, processed: processed, already_in_db: already_in_db)
  end

  #
  # Отправляет результат импорта админу
  #
  # @param user [User] админ, инициировавший импорт
  # @param stats [Hash] статистика { created:, skipped_duplicate:, skipped_modified:, errors: }
  # @param category [PoiCategory] категория, для которой выполнялся импорт
  # @param bbox [Array<Float>, nil] границы импорта [south, west, north, east] —
  #   используется для гео-фильтрации reload карты (баг 4)
  #
  def self.call(user:, stats:, category:, bbox: nil)
    new(user: user).broadcast(stats: stats, category: category, bbox: bbox)
  end

  #
  # Отправляет промежуточный прогресс импорта из .pbf файла.
  # В PBF-режиме общее количество записей заранее неизвестно (стриминг),
  # поэтому передаётся только счётчик обработанных.
  #
  # @param user [User] админ, инициировавший импорт
  # @param processed [Integer] сколько записей обработано
  #
  def self.pbf_progress(user:, processed:)
    new(user: user).pbf_progress(processed: processed)
  end

  #
  # Отправляет сообщение об ошибке импорта
  #
  # @param user [User, nil] админ, инициировавший импорт
  # @param message [String] текст ошибки
  #
  def self.failed(user:, message:)
    new(user: user).failed(message: message) if user
  end

  attr_reader :user

  def initialize(user:)
    @user = user
  end

  #
  # Отправляет сигнал о старте импорта
  # Вызывается из OsmImportJob перед fetch_elements
  #
  def send_started(category:)
    cable_ready["user_#{user.id}"].dispatch_event(
      name: "osmImportStarted",
      detail: {
        category_id: category.id,
        category_name: category.localized_name
      }
    )
    cable_ready.broadcast
  rescue StandardError => e
    Rails.logger.error "OsmImportBroadcaster#started error: #{e.class} #{e.message}"
  end

  #
  # Отправляет промежуточный прогресс через dispatch_event
  #
  # @param total [Integer] общее количество элементов из OSM
  # @param processed [Integer] сколько обработано
  # @param already_in_db [Integer, nil] сколько уже есть в БД (только для processed=0)
  #
  def progress(total:, processed:, already_in_db: nil)
    cable_ready["user_#{user.id}"].dispatch_event(
      name: "osmImportProgress",
      detail: {
        total: total,
        processed: processed,
        already_in_db: already_in_db
      }
    )
    cable_ready.broadcast
    Rails.logger.info "[TRACE] OsmImportBroadcaster#progress sent: #{processed}/#{total} already_in_db=#{already_in_db}"
  rescue StandardError => e
    Rails.logger.error "[TRACE] OsmImportBroadcaster#progress error: #{e.class} #{e.message}"
  end

  #
  # Отправляет промежуточный прогресс импорта из .pbf (только каунтер обработанных)
  #
  # @param processed [Integer] сколько записей обработано
  #
  def pbf_progress(processed:)
    cable_ready["user_#{user.id}"].dispatch_event(
      name: "osmPbfProgress",
      detail: { processed: processed }
    )
    cable_ready.broadcast
  rescue StandardError => e
    Rails.logger.error "[TRACE] OsmImportBroadcaster#pbf_progress error: #{e.class} #{e.message}"
  end

  #
  # Отправляет сообщение об ошибке импорта
  #
  # @param message [String] текст ошибки
  #
  def failed(message:)
    cable_ready["user_#{user.id}"].dispatch_event(
      name: "osmImportFailed",
      detail: { message: message }
    )
    cable_ready.broadcast
  rescue StandardError => e
    Rails.logger.error "[TRACE] OsmImportBroadcaster#failed error: #{e.class} #{e.message}"
  end

  #
  # Выполняет broadcast финального результата импорта
  #
  # ВАЖНО: dispatch_event отправляется ДО рендера компонента, т.к.
  # ApplicationController.render может упасть с Warden error вне
  # веб-контекста (VersionObserverJob в SolidQueue worker'е).
  # Если упадёт — osmImportComplete уже ушёл клиенту.
  #
  # @param stats [Hash] статистика импорта
  # @param category [PoiCategory] категория импорта
  # @param bbox [Array<Float>, nil] границы [south, west, north, east] для
  #   гео-фильтрации reload карты (баг 4). Если nil — reload у всех подписанных.
  #
  def broadcast(stats:, category:, bbox: nil)
    Rails.logger.info "[TRACE] OsmImportBroadcaster#broadcast START: stats=#{stats.inspect}"

    # 1. Отправляем событие с результатами импорта — НЕМЕДЛЕННО
    cable_ready["user_#{user.id}"].dispatch_event(
      name: "osmImportComplete",
      detail: {
        category_id: category.id,
        category_name: category.localized_name,
        created: stats[:created],
        skipped_duplicate: stats[:skipped_duplicate],
        skipped_modified: stats[:skipped_modified],
        errors: stats[:errors]
      }
    )
    Rails.logger.info "[TRACE] OsmImportBroadcaster#broadcast: osmImportComplete queued for user_#{user.id}"

    # 2. Триггерим перезагрузку маркеров на карте — тоже немедленно.
    #    В detail передаём bbox импорта: клиент перезагружает POI только если
    #    его видимые границы пересекаются с областью импорта (баг 4).
    #    Уходит в общий поток карты "pois_map" (раньше: мёртвый "UserChannel",
    #    т.к. подписка идёт на user_N + pois_map, а не на глобальный "UserChannel").
    reload_detail = { type: "osm", category_id: category.id }
    reload_detail[:bbox] = bbox if bbox
    cable_ready["pois_map"].dispatch_event(
      name: "poi:reload-features",
      detail: reload_detail
    )
    Rails.logger.info "[TRACE] OsmImportBroadcaster#broadcast: poi:reload-features queued for pois_map (bbox=#{bbox.inspect})"

    # Отправляем эти события сразу (гарантированная доставка)
    cable_ready.broadcast
    Rails.logger.info "[TRACE] OsmImportBroadcaster#broadcast: first broadcast done"

    # 3. Обновляем ВСЕ зоны категории единым кодом PoiCategoryBroadcaster (inner_html):
    #    карточку, список полей, ВКЛАДКУ POIs ([data-poi-category-pois]) и ленту аудита —
    #    чтобы новые импортированные POI появились во вкладке.
    #    Ранее здесь был отдельный cable_ready.morph на [data-admin-poi-category-id] —
    #    удалён: двойное обновление #poi-category-detail (морф + inner_html) и падение
    #    morph на клиенте (undefined.dispatchEvent; догма «Broadcaster — только inner_html»).
    #    PoiCategoryBroadcaster также рассылает уведомления (PoiCategoryNotification)
    #    инициатору и всем админам по их личным настройкам (event_type "osm_import").
    begin
      PoiCategoryBroadcaster.call(
        category: category.reload,
        event_type: "osm_import",
        payload: { stats: stats, initiator_id: user.id }
      )
    rescue StandardError => e
      Rails.logger.warn "[TRACE] OsmImportBroadcaster: PoiCategoryBroadcaster skipped: #{e.class} #{e.message}"
    end

    Rails.logger.info "[TRACE] OsmImportBroadcaster#broadcast: sent result to user##{user.id} for category##{category.id}"
  rescue StandardError => e
    Rails.logger.error "[TRACE] OsmImportBroadcaster error: #{e.class} #{e.message}"
  end
end
