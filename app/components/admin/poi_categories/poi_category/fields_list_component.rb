# frozen_string_literal: true

#
# Admin::PoiCategories::PoiCategory::FieldsListComponent - список полей категории POI в админке
#
# Вкладка "Fields" детальной страницы категории: таблица полей + форма создания/редактирования.
#
class Admin::PoiCategories::PoiCategory::FieldsListComponent < ApplicationComponent
  attr_reader :category

  #
  # @param category [PoiCategory] категория POI
  #
  def initialize(category:)
    @category = category
  end

  #
  # Возвращает поля категории, отсортированные по позиции
  #
  # @return [ActiveRecord::Relation<PoiCategoryField>]
  #
  def fields
    category.poi_category_fields.by_position
  end

  #
  # Является ли переданное поле последним в списке?
  # Используется в шаблоне для определения кнопки реордера (Herb: не вызывать fields в `<% %>`)
  #
  # @param field [PoiCategoryField] поле
  # @return [Boolean]
  #
  def last_field?(field)
    field == fields.last
  end
end
