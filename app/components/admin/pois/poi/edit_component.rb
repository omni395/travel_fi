# frozen_string_literal: true

#
# Admin::Pois::Poi::EditComponent - форма редактирования POI
#
# Отображает форму с полями:
# - name (JSONB, 4 локали)
# - slug
# - description (JSONB, 4 локали)
# - poi_category_id (select)
# - status (select)
# - coordinates (карта или поля lat/lng)
# - address, city, country, zip_code
# - phone, website
# - price_info, wheelchair_accessible, rating
# - opening_hours (JSONB)
# - osm_id (readonly)
# - metadata (динамические поля категории)
#
# @param poi [Poi] объект POI для редактирования
# @param categories [ActiveRecord::Relation<PoiCategory>] список категорий
#
class Admin::Pois::Poi::EditComponent < ApplicationComponent
  def initialize(poi:, categories:)
    @poi = poi
    @categories = categories
  end

  private

  attr_reader :poi, :categories

  #
  # Доступные локали для перевода
  #
  # @return [Array<String>]
  #
  def locales
    %w[en ru es zh]
  end

  #
  # Возвращает значение локализованного поля для указанной локали
  #
  # @param field [Symbol] поле (:name, :description)
  # @param locale [String] код локали
  # @return [String]
  #
  def localized_value(field, locale)
    val = poi.public_send(field)
    val.is_a?(Hash) ? val[locale].to_s : val.to_s
  end

  #
  # Динамические поля категории
  #
  # @return [ActiveRecord::Relation<PoiCategoryField>]
  #
  def category_fields
    poi.poi_category&.poi_category_fields&.active&.by_position || []
  end

  #
  # Значение динамического поля из metadata
  #
  # @param field [PoiCategoryField] поле категории
  # @return [Object] значение
  #
  def metadata_value(field)
    poi.metadata[field.field_key]
  end

  #
  # Опции для select/multiselect полей
  #
  # @param field [PoiCategoryField] поле категории
  # @return [Array] массив опций
  #
  def field_options(field)
    (field.options['values'] || field.options[:values] || []).map { |v| [v, v] }
  end

  #
  # Локализованное название выбранной категории (для DropdownComponent)
  #
  # @return [String]
  #
  def category_name
    poi.poi_category&.localized_name || I18n.t("admin.pois.poi.edit_component.category_prompt")
  end

  #
  # Локализованная подпись текущего статуса (для DropdownComponent)
  #
  # @return [String]
  #
  def status_label
    I18n.t("admin.pois.poi.row_component.status.#{poi.status}", default: poi.status.humanize)
  end

  #
  # Опции статусов для DropdownComponent
  #
  # @return [Array<Array(String, String)>] массив [label, value]
  #
  def status_options
    Poi.statuses.keys.map { |s| [I18n.t("admin.pois.poi.row_component.status.#{s}", default: s.humanize), s] }
  end
end
