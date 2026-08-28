# frozen_string_literal: true

#
# Admin::PoiCategories::PoiCategory::FieldFormComponent — диалог создания/редактирования поля категории POI
#
# @param category [PoiCategory] категория POI
# @param field [PoiCategoryField, nil] поле для редактирования (nil = создание)
#
class Admin::PoiCategories::PoiCategory::FieldFormComponent < ApplicationComponent
  def initialize(category:, field: nil)
    @category = category
    @field = field
  end

  private

  attr_reader :category, :field

  #
  # Поле для формы (новое или существующее)
  #
  def form_field
    field || category.poi_category_fields.new
  end

  #
  # Режим редактирования?
  #
  def edit_mode?
    field.present?
  end

  #
  # Доступные типы полей
  #
  def field_type_options
    %w[string text number boolean select multiselect].map { |t|
      [ I18n.t("admin.poi_categories.poi_category.field_form_component.field_types.#{t}"), t ]
    }
  end

  #
  # Доступные локали
  #
  def locales
    %w[en ru es zh]
  end

  #
  # Следующая позиция
  #
  def next_position
    (category.poi_category_fields.maximum(:position) || 0) + 1
  end

  #
  # Сериализует options поля в текстовый формат для textarea:
  # каждая строка "key;en;ru;es;zh" (пустые локали пропускаются).
  # Формат симметричен парсингу на клиенте (FieldFormController#_parseOptions).
  #
  # @param field [PoiCategoryField, nil] поле (nil = режим создания)
  # @return [String] текст для textarea
  #
  def options_editor_text(field)
    values = field&.options&.dig("values") || field&.options&.dig(:values) || []
    values.map do |v|
      key = v.is_a?(Hash) ? (v["key"] || v[:key]) : v.to_s
      label = v.is_a?(Hash) ? (v["label"] || v[:label] || {}) : {}
      parts = [ key.to_s ]
      locales.each do |locale|
        value = label[locale].to_s
        parts << value unless value.blank?
      end
      parts.join(";")
    end.join("\n")
  end
end
