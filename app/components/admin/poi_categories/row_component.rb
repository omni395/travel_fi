# frozen_string_literal: true

#
# Admin::PoiCategories::RowComponent - строка таблицы категорий POI
#
# @param category [PoiCategory] категория POI для отображения
#
class Admin::PoiCategories::RowComponent < ApplicationComponent
  def initialize(category:)
    @category = category
  end

  private

  attr_reader :category
end
