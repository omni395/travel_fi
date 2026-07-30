# frozen_string_literal: true

#
# Admin::PoiCategories::FieldFormComponent — диалог создания/редактирования поля категории POI
#
# @param category [PoiCategory] категория POI
# @param field [PoiCategoryField, nil] поле для редактирования (nil = создание)
#
class Admin::PoiCategories::FieldFormComponent < ApplicationComponent
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
      [I18n.t("admin.poi_categories.field_form_component.field_types.#{t}"), t]
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
end
