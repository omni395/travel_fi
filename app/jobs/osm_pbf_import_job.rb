# frozen_string_literal: true

#
# OsmPbfImportJob — фоновый джоб (SolidQueue) импорта POI из файла .osm.pbf
#
# Ответственность:
# 1. Вызывает OsmPbfImportService (стриминг .pbf без загрузки в память)
# 2. Отправляет прогресс через OsmImportBroadcaster (started + pbf_progress + call)
# 3. В ensure удаляет загруженный временный .pbf файл с диска
#
# @example
#   OsmPbfImportJob.perform_later(category_id: 3, file_path: "/tmp/import.uuid.osm.pbf", user_id: 1)
#
class OsmPbfImportJob < ApplicationJob
  queue_as :default

  # Интервал (в обработанных записях) для отправки прогресса
  PROGRESS_INTERVAL = 100

  #
  # Выполняет импорт из .pbf
  #
  # @param category_id [Integer] ID категории POI
  # @param file_path [String] путь к временному .osm.pbf файлу
  # @param user_id [Integer] ID админа, инициировавшего импорт
  #
  def perform(category_id, file_path, user_id)
    category = PoiCategory.find_by(id: category_id)
    user = User.find_by(id: user_id)

    unless category && user
      Rails.logger.error "OsmPbfImportJob: category##{category_id} or user##{user_id} not found"
      return
    end

    OsmImportBroadcaster.started(user: user, category: category)

    stats = OsmPbfImportService.call(
      category: category,
      file_path: file_path,
      user: user
    ) do |processed|
      # Промежуточный прогресс: каунтер обработанных записей каждые N и в конце
      if (processed % PROGRESS_INTERVAL).zero?
        OsmImportBroadcaster.pbf_progress(user: user, processed: processed)
      end
    end

    # Финальный результат (сводка + обновление вкладки POIs)
    OsmImportBroadcaster.call(user: user, stats: stats, category: category)

    Rails.logger.info "OsmPbfImportJob: complete for category##{category_id} (#{category.localized_name}): " \
                      "#{stats[:created]} created, #{stats[:skipped_duplicate]} duplicate, " \
                      "#{stats[:skipped_modified]} modified, #{stats[:errors]} errors"
  rescue OsmPbfImportService::ImportError => e
    OsmImportBroadcaster.failed(user: user, message: e.message) if user
    Rails.logger.error "OsmPbfImportJob: import error: #{e.message}"
  rescue ArgumentError => e
    Rails.logger.error "OsmPbfImportJob: invalid arguments: #{e.message}"
  rescue StandardError => e
    Rails.logger.error "OsmPbfImportJob: unexpected error: #{e.class} #{e.message}"
  ensure
    # КРИТИЧНО: удаляем временный .pbf файл после завершения (успех или ошибка)
    delete_uploaded_file(file_path)
  end

  private

  #
  # Удаляет временный загруженный .pbf файл (безопасно, не роняя джоб)
  #
  # @param file_path [String, nil] путь к файлу
  #
  def delete_uploaded_file(file_path)
    return if file_path.blank?

    File.delete(file_path) if File.exist?(file_path)
  rescue StandardError => e
    Rails.logger.warn "OsmPbfImportJob: failed to delete #{file_path}: #{e.message}"
  end
end
