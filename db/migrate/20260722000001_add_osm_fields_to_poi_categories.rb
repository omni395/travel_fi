# frozen_string_literal: true

#
# Миграция добавляет OSM-поля в таблицу poi_categories
# osm_tags: массив OSM-тегов для Overpass запроса (["amenity=toilets", "amenity=shower"])
# osm_default_name: мультиязычное название для точек без name в OSM
#
class AddOsmFieldsToPoiCategories < ActiveRecord::Migration[8.1]
  def change
    add_column :poi_categories, :osm_tags, :jsonb, default: []
    add_column :poi_categories, :osm_default_name, :jsonb, default: {}

    add_index :poi_categories, :osm_tags, using: :gin
  end
end
