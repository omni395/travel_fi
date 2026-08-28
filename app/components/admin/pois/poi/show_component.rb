# frozen_string_literal: true

#
# Admin::Pois::Poi::ShowComponent - детальная страница POI в админке
#
# Отображает:
# - Алерт о незаполненных переводах
# - Заголовок, категорию, статус
# - Детали: описание, адрес, телефон, вебсайт, координаты
# - Метаданные (динамические поля категории)
# - Мини-карту с точкой POI
# - Информацию о создателе
#
# @param poi [Poi] объект POI для отображения
#
class Admin::Pois::Poi::ShowComponent < ApplicationComponent
  def initialize(poi:)
    @poi = poi
  end

  private

  attr_reader :poi

  #
  # Возвращает CSS класс для бейджа статуса
  #
  # @return [String] CSS класс
  #
  def status_badge_class
    case poi.status
    when "approved" then "bg-green-100 text-green-800"
    when "pending" then "bg-yellow-100 text-yellow-800"
    when "rejected" then "bg-red-100 text-red-800"
    when "archived" then "bg-gray-100 text-gray-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  #
  # Возвращает сообщение о незаполненных переводах
  #
  # @return [String]
  #
  def missing_translations_message
    I18n.t("admin.pois.show_component.missing_translations",
           locales: poi.missing_translations.map(&:to_s).join(", "))
  end

  #
  # Возвращает массив метаданных с label из PoiCategoryField
  #
  # @return [Array<Hash>] массив { label:, value:, field_type: }
  #
  def metadata_fields
    return [] if poi.metadata.blank?

    field_map = poi.poi_category.poi_category_fields.active.index_by(&:field_key)
    poi.metadata.map do |key, value|
      field = field_map[key]
      {
        label: field&.localized_label || key.humanize,
        value: value,
        field_type: field&.field_type
      }
    end
  end
end
