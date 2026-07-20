# frozen_string_literal: true

#
# Admin::PoiCategories::FieldsListComponent - список полей категории POI в админке
#
class Admin::PoiCategories::FieldsListComponent < ApplicationComponent
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
end
