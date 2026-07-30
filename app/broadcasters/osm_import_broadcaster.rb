# frozen_string_literal: true

#
# OsmImportBroadcaster — отправляет прогресс и результаты импорта OSM через WebSocket
#
# Ответственность:
# 1. progress — отправляет промежуточный прогресс импорта (total/processed)
# 2. call — отправляет финальный результат импорта + обновляет UI
#
class OsmImportBroadcaster
  include CableReady::Broadcaster

  #
  # Отправляет промежуточный прогресс импорта
  #
  # @param user [User] админ, инициировавший импорт
  # @param total [Integer] общее количество элементов из OSM
  # @param processed [Integer] сколько обработано
  #
  def self.progress(user:, total:, processed:)
    new(user: user).progress(total: total, processed: processed)
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
  # Отправляет промежуточный прогресс через dispatch_event
  #
  def progress(total:, processed:)
    cable_ready["user_#{user.id}"].dispatch_event(
      name: "osmImportProgress",
      detail: { total: total, processed: processed }
    )
    cable_ready.broadcast
  end

  #
  # Выполняет broadcast финального результата импорта
  #
  def broadcast(stats:, category:)
    # Отправляем событие с результатами импорта в UserChannel пользователя
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

    # Обновляем UI (счётчик POI) — отправляем в AdminChannel для всех админов
    component = Admin::PoiCategories::PoiCategory::ShowComponent.new(category: category.reload)
    html = ApplicationController.render(component, layout: false)
    cable_ready["AdminChannel"].morph(
      selector: "[data-admin-poi-category-id='#{category.id}']",
      html: html
    )

    cable_ready.broadcast

    Rails.logger.info "OsmImportBroadcaster: sent result to user##{user.id} for category##{category.id}"
  rescue StandardError => e
    Rails.logger.error "OsmImportBroadcaster error: #{e.class} #{e.message}"
  end
end
