# frozen_string_literal: true

namespace :photos do
  desc "Конвертирует существующие active_storage галеры POI (has_many_attached :photos) в модель Photo (poi_id, user_id, position)"
  task convert_to_model: :environment do
    # Находим все ActiveStorage::Attachment, привязанные к Poi по имени :photos
    attachments = ActiveStorage::Attachment.where(record_type: "Poi", name: "photos").order(:record_id, :id)

    converted = 0
    skipped = 0

    attachments.group_by(&:record_id).each do |poi_id, list|
      poi = Poi.find_by(id: poi_id)
      unless poi
        skipped += list.size
        next
      end

      list.each_with_index do |attachment, index|
        # Пропускаем записи, которые уже конвертированы в Photo (дубликат)
        if Photo.exists?(poi_id: poi_id)
          skipped += 1
          next
        end

        photo = Photo.new(poi: poi, user: poi.user, position: index)
        # Переносим blob-данные: копируем content_type/byte_size без физического
        # перемещения файла (используем тот же blob через attach аттачмента)
        photo.image.attach(blob: attachment.blob)
        photo.save!
        converted += 1
      end
    end

    # После конвертации чистим старые attachment-записи галереи (если нужно)
    puts "Photos converted: #{converted}, skipped: #{skipped}"
  end
end
