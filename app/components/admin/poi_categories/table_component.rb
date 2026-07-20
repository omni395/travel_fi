# frozen_string_literal: true

#
# Admin::PoiCategories::TableComponent - таблица категорий POI для админки
#
class Admin::PoiCategories::TableComponent < ApplicationComponent
  attr_reader :categories, :pagy

  #
  # @param categories [ActiveRecord::Relation] список категорий
  # @param pagy [Pagy, nil] объект пагинации
  #
  def initialize(categories:, pagy: nil)
    @categories = categories
    @pagy = pagy
  end
end
