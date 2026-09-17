# frozen_string_literal: true

#
# Poi::FormFieldsComponent — динамические поля выбранной категории POI
#
# Рендерится сервером в PoiReflex#load_category_fields и доставляется в форму
# через cable_ready.inner_html в целевую обёртку [data-poi-form-fields].
# Представление только: берёт активные поля категории и рисует инпуты по
# field_type (string/text/number/boolean/select/multiselect), неймспейс
# name="poi[metadata][field_key]" для сохранения в PoiService.
#
# @param category [PoiCategory] категория, поля которой отображаются
#
class Poi::FormFieldsComponent < ApplicationComponent
  def initialize(category:)
    @category = category
  end

  private

  attr_reader :category

  #
  # Активные поля категории, отсортированные по позиции
  #
  # @return [ActiveRecord::Relation<PoiCategoryField>]
  #
  def fields
    category.poi_category_fields.active.by_position
  end

  #
  # Опции для select/multiselect поля в формате [[value, label], ...]
  #
  # Значения из JSONB options.values могут быть строками или хэшами
  # { key:, label: { en:, ru:, ... } }. Локализованная метка — по текущему
  # I18n.locale c фолбэком на en.
  #
  # @param field [PoiCategoryField] поле категории
  # @return [Array<Array(String, String)>] пары value → label
  #
  def field_options(field)
    values = field.options&.dig("values") || field.options&.dig(:values) || []
    values.map do |value|
      if value.is_a?(Hash)
        key = (value["key"] || value[:key]).to_s
        label = value["label"] || value[:label] || {}
        localized = label[I18n.locale.to_s] || label["en"].to_s || key
        [key, localized]
      else
        [value.to_s, value.to_s]
      end
    end
  end
end
