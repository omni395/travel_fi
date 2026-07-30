# frozen_string_literal: true

#
# OsmImportJob — фоновый джоб для импорта POI из OpenStreetMap
#
# Запускается через SolidQueue.
# Вызывает OsmImportService, отправляет прогресс через Broadcaster.
#
# @example
#   OsmImportJob.perform_later(category.id, { city: "London", country: "UK", bbox: [51.3, -0.5, 51.7, 0.3] }, current_user.id)
#
class OsmImportJob < ApplicationJob
  queue_as :default

  # Частота отправки прогресса (каждые N элементов)
  PROGRESS_INTERVAL = 10

  #
  # Выполняет импорт POI из OSM
  #
  # @param category_id [Integer] ID категории POI
  # @param location [Hash] { city:, country:, bbox: [s, w, n, e] }
  # @param user_id [Integer] ID пользователя, инициировавшего импорт
  #
  def perform(category_id, location, user_id)
    category = PoiCategory.find_by(id: category_id)
    user = User.find_by(id: user_id)

    unless category && user
      Rails.logger.error "OsmImportJob: category##{category_id} or user##{user_id} not found"
      return
    end

    # Этап 1: Получаем элементы из Overpass
    elements = OsmImportService.fetch_elements(category: category, location: location, user: user)
    total = elements.size

    # Отправляем прогресс: найдено N элементов, обработано 0
    OsmImportBroadcaster.progress(user: user, total: total, processed: 0)

    # Этап 2: Обрабатываем элементы с прогрессом
    stats = OsmImportService.process_elements(
      elements: elements,
      category: category,
      location: location,
      user: user
    ) do |processed|
      # Отправляем прогресс каждые PROGRESS_INTERVAL элементов и на последнем
      OsmImportBroadcaster.progress(user: user, total: total, processed: processed) if processed % PROGRESS_INTERVAL == 0 || processed == total
    end

    # Финальный результат
    OsmImportBroadcaster.call(user: user, stats: stats, category: category)

    Rails.logger.info "OsmImportJob: complete for category##{category_id} (#{category.localized_name}): " \
                      "#{stats[:created]} created, #{stats[:skipped_duplicate]} duplicate, " \
                      "#{stats[:skipped_modified]} modified, #{stats[:errors]} errors"
  rescue ArgumentError => e
    Rails.logger.error "OsmImportJob: invalid arguments: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "OsmImportJob: unexpected error: #{e.class} #{e.message}"
  end
end
