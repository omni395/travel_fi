# frozen_string_literal: true

#
# Миграция добавляет OSM-маппинг в таблицу poi_category_fields.
# Позволяет админу привязать поле категории к тегам OpenStreetMap для
# автоматического извлечения значения при OSM-импорте (см. OsmValueTransformer).
#
# Столбцы:
#   osm_keys       — массив тегов OSM, из которых берётся значение (["charge","fee"])
#   osm_value_map  — карта соответствий «сырое значение OSM» → «значение приложения» ({ "yes": true })
#   osm_transform  — тип трансформера: nil | "boolean" | "extract_number" | "split_array"
#
class AddOsmMappingToPoiCategoryFields < ActiveRecord::Migration[8.1]
  def change
    change_table :poi_category_fields, bulk: true do |t|
      t.jsonb :osm_keys, default: []
      t.jsonb :osm_value_map, default: {}
      t.string :osm_transform
    end
  end
end
