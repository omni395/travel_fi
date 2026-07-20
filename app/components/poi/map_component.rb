# frozen_string_literal: true

#
# Poi::MapComponent - контейнер для OpenLayers карты
#
# Содержит контейнер карты, тултип и оверлей фильтров (только lg+).
# Вся логика инициализации карты, маркеров и геолокации — в Stimulus-контроллере.
#
# Контроллер: poi--map-component
#
# @param categories [ActiveRecord::Relation<PoiCategory>, nil] список категорий для фильтров
# @param poi [Poi, nil] одиночная POI для показа на карте (админка)
# @param interactive [Boolean] режим редактирования: клик/перетаскивание маркера обновляет координаты
#
class Poi::MapComponent < ApplicationComponent
  def initialize(categories: nil, poi: nil, interactive: false)
    @categories = categories
    @poi = poi
    @interactive = interactive
  end

  private

  attr_reader :categories, :poi, :interactive
end
