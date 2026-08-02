# frozen_string_literal: true

#
# Admin::PoiCategories::PoiCategory::PoisListComponent - список POI категории
#
# Отображает POI данной категории в виде таблицы
#
# @param category [PoiCategory] категория POI
#
class Admin::PoiCategories::PoiCategory::PoisListComponent < ApplicationComponent
  #
  # @param category [PoiCategory] категория POI
  # @param pagy [Pagy] объект пагинации Pagy
  # @param pois [ActiveRecord::Relation<Poi>] POI текущей страницы
  #
  def initialize(category:, pagy:, pois:)
    @category = category
    @pagy = pagy
    @pois = pois
  end

  private

  attr_reader :category, :pagy, :pois
end
