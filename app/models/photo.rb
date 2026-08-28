# frozen_string_literal: true

#
# Photo — фотография галереи POI.
#
# Каждая фото принадлежит POI и автору (user). Хранит attachment :image
# (ActiveStorage) и позицию (position) для сортировки/cover.
#
# Фото НЕ трекается PaperTrail напрямую: PoiService фиксирует изменение галереи
# через poi.touch (создаёт версию обновления POI → VersionObserverJob → Broadcaster).
#
# @attr poi_id [Integer] ссылка на POI
# @attr user_id [Integer] автор фото
# @attr position [Integer] позиция в галерее (0 = cover)
# @attr image [ActiveStorage::Attached] загруженное изображение
#
class Photo < ApplicationRecord
  # ActiveStorage — само изображение
  has_one_attached :image

  # Ассоциации
  belongs_to :poi
  belongs_to :user

  # Валидации
  validates :image, presence: true

  # Скоупы
  scope :ordered, -> { order(:position, :id) }
  # Свои фото автора current_user — первыми (position), затем остальные
  scope :author_first, ->(user_id) {
    order(Arel.sql("(CASE WHEN user_id = #{user_id.to_i} THEN 0 ELSE 1 END), position, id"))
  }

  #
  # Возвращает URL изображения для заданного варианта (относительный путь).
  # Если вариант не указан или не image — путь к полному блобу.
  #
  # @param variant [Hash, nil] опции ресайза (THUMB/MEDIUM)
  # @return [String, nil] URL изображения или nil
  #
  def url(variant: nil)
    return nil unless image.attached?

    if image.image? && variant
      Rails.application.routes.url_helpers.rails_representation_path(image.variant(variant), only_path: true)
    else
      Rails.application.routes.url_helpers.rails_blob_path(image, only_path: true)
    end
  rescue StandardError => e
    Rails.logger.warn("Photo##{id} url failed: #{e.message}")
    nil
  end
end
