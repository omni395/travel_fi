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
  #
  def self.call(user:, stats:, category:)
    new(user: user).broadcast(stats: stats, category: category)
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
  # Выполняет broadcast финального результата импорта
  #
  # ВАЖНО: dispatch_event отправляется ДО рендера компонента, т.к.
  # ApplicationController.render может упасть с Warden error вне
  # веб-контекста (VersionObserverJob в SolidQueue worker'е).
  # Если упадёт — osmImportComplete уже ушёл клиенту.
  #
  def broadcast(stats:, category:)
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

    # 2. Триггерим перезагрузку маркеров на карте — тоже немедленно
    cable_ready["UserChannel"].dispatch_event(
      name: "poi:reload-features"
    )
    Rails.logger.info "[TRACE] OsmImportBroadcaster#broadcast: poi:reload-features queued for UserChannel"

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
