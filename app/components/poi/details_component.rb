# frozen_string_literal: true

#
# Poi::DetailsComponent — таб «Детали» карточки POI
#
# Содержит полную детальную информацию о точке:
# описание, контакты, часы работы, цены, доступность, метаданные категории,
# источник (manual/osm + OSM ID), автор и блок «Расположение» с мини-картой,
# координатами и ссылками (копирование / открыть в картах / маршрут).
#
# @param poi [Poi] объект POI
#
class Poi::DetailsComponent < ApplicationComponent
  attr_reader :poi

  def initialize(poi:)
    @poi = poi
  end

  private

  #
  # Массив метаданных с label из PoiCategoryField
  #
  # @return [Array<Hash>] { label:, value:, field_type: }
  #
  def metadata_fields
    return [] if poi.metadata.blank?

    field_map = poi.poi_category.poi_category_fields.active.index_by(&:field_key)
    poi.metadata.map do |key, value|
      field = field_map[key]
      {
        label: field&.localized_label || key.humanize,
        value: value,
        field_type: field&.field_type
      }
    end
  end

  #
  # Полный адрес одной строкой
  #
  # @return [String]
  #
  def full_address
    [poi.address, poi.city, poi.country].compact.join(", ")
  end

  #
  # Ссылка на карту (Google Maps) по координатам
  #
  # @return [String, nil]
  #
  def maps_url
    return nil if poi.latitude.blank? || poi.longitude.blank?

    "https://www.google.com/maps?q=#{poi.latitude},#{poi.longitude}"
  end

  #
  # Ссылка на маршрут (Google Maps directions) по координатам
  #
  # @return [String, nil]
  #
  def directions_url
    return nil if poi.latitude.blank? || poi.longitude.blank?

    "https://www.google.com/maps/dir/?api=1&destination=#{poi.latitude},#{poi.longitude}"
  end

  #
  # Строка координат "lat, lng"
  #
  # @return [String, nil]
  #
  def coordinates_text
    return nil if poi.latitude.blank? || poi.longitude.blank?

    "#{poi.latitude}, #{poi.longitude}"
  end

  #
  # Локализованное название источника (OSM / вручную)
  #
  # @return [String]
  #
  def source_label
    case poi.source
    when "osm" then t(".source_osm")
    else t(".source_manual")
    end
  end
end
