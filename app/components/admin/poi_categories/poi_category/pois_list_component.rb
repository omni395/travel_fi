# frozen_string_literal: true

#
# Admin::PoiCategories::PoiCategory::PoisListComponent - список POI категории
#
# Отображает POI данной категории в виде таблицы
#
# @param category [PoiCategory] категория POI
#
class Admin::PoiCategories::PoiCategory::PoisListComponent < ApplicationComponent
  def initialize(category:)
    @category = category
  end

  private

  attr_reader :category

  #
  # POI данной категории, отсортированные по дате создания
  #
  # @return [ActiveRecord::Relation<Poi>]
  #
  def pois
    category.pois.includes(:user).order(created_at: :desc).limit(50)
  end
end
