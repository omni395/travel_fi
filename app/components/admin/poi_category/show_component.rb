# frozen_string_literal: true

#
# Admin::PoiCategory::ShowComponent - детальная страница категории POI в админке
#
class Admin::PoiCategory::ShowComponent < ApplicationComponent
  attr_reader :category

  #
  # @param category [PoiCategory] категория POI
  #
  def initialize(category:)
    @category = category
  end
end
