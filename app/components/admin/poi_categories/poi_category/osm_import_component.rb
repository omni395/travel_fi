# frozen_string_literal: true

#
# Admin::PoiCategories::PoiCategory::OsmImportComponent — диалог импорта POI из OSM
#
# Отображает модальное окно с выбором города/локации для импорта.
# После выбора запускает OsmImportJob через StimulusReflex.
#
# @param category [PoiCategory] категория для импорта
#
class Admin::PoiCategories::PoiCategory::OsmImportComponent < ApplicationComponent
  # Предустановленные города с bbox для быстрого выбора
  CITIES = {
    "London"      => { bbox: [ 51.3, -0.5, 51.7, 0.3 ],           country: "United Kingdom" },
    "Paris"       => { bbox: [ 48.8, 2.2, 48.9, 2.5 ],             country: "France" },
    "Berlin"      => { bbox: [ 52.3, 13.2, 52.7, 13.6 ],           country: "Germany" },
    "Tokyo"       => { bbox: [ 35.6, 139.6, 35.8, 139.9 ],         country: "Japan" },
    "New York"    => { bbox: [ 40.6, -74.1, 40.8, -73.9 ],         country: "USA" },
    "Bangkok"     => { bbox: [ 13.7, 100.4, 13.8, 100.6 ],         country: "Thailand" },
    "Dubai"       => { bbox: [ 25.2, 55.2, 25.3, 55.4 ],           country: "UAE" },
    "Sydney"      => { bbox: [ -33.9, 151.1, -33.8, 151.3 ],       country: "Australia" },
    "Singapore"   => { bbox: [ 1.2, 103.6, 1.5, 104.0 ],           country: "Singapore" },
    "Istanbul"    => { bbox: [ 41.0, 28.9, 41.1, 29.1 ],           country: "Turkey" },
    "Kryvyi Rih"  => { bbox: [ 47.8, 33.2, 48.1, 33.7 ],           country: "Ukraine" }
  }.freeze

  def initialize(category:)
    @category = category
  end

  private

  attr_reader :category

  #
  # Массив городов для JS citiesValue
  # Каждый город дополняется poi_count — сколько POI этой категории уже есть в его bbox
  #
  # @return [Hash] { "City" => { bbox: [...], country: "...", poi_count: Integer } }
  #
  def cities_data
    CITIES.transform_values do |data|
      count = category.pois.within_bounds(*data[:bbox]).count
      data.merge(poi_count: count)
    end
  end

  #
  # Есть ли у категории OSM-теги для импорта
  #
  # @return [Boolean]
  #
  def can_import?
    category.osm_tags.is_a?(Array) && category.osm_tags.any?
  end
end
