# frozen_string_literal: true

#
# Миграция создания таблицы pois (Points of Interest)
# Единая таблица для всех категорий POI с динамическими полями в metadata
# Координаты через raw SQL geography(Point, 4326) — не зависит от activerecord-postgis-adapter
#
class CreatePois < ActiveRecord::Migration[8.0]
  def change
    create_table :pois do |t|
      t.jsonb :name, null: false, default: {}    # JSONB { en: "...", ru: "...", es: "...", zh: "..." }
      t.jsonb :description, default: {}          # JSONB { en: "...", ru: "...", es: "...", zh: "..." }
      t.bigint :osm_id                                            # ID из OpenStreetMap (null если добавлен вручную)
      t.references :poi_category, null: false, foreign_key: true
      t.string :address
      t.string :city
      t.string :country
      t.string :zip_code
      t.integer :status, null: false, default: 0                 # 0=pending, 1=approved, 2=rejected, 3=archived
      t.references :user, null: false, foreign_key: true
      t.decimal :rating, precision: 3, scale: 2, default: 0.0
      t.jsonb :metadata, null: false, default: {}                # динамические поля категории
      t.string :phone
      t.string :website
      t.boolean :wheelchair_accessible, default: false
      t.jsonb :opening_hours, default: {}                        # OSM формат часов работы
      t.string :price_info
      t.integer :verification_count, default: 0
      t.datetime :last_verified_at
      t.string :slug, null: false
      t.timestamps
    end

    # Координаты через raw SQL — geography(Point, 4326) из PostGIS
    execute "ALTER TABLE pois ADD COLUMN coordinates geography(Point, 4326) NOT NULL"

    add_index :pois, :slug, unique: true
    # Индекс на poi_category_id уже создаётся автоматически через t.references
    add_index :pois, :status
    # GIST-индекс для координат через raw SQL
    execute "CREATE INDEX index_pois_on_coordinates ON pois USING GIST (coordinates)"
    add_index :pois, :metadata, using: :gin
    add_index :pois, [:status, :poi_category_id]
    add_index :pois, :osm_id, unique: true, where: "osm_id IS NOT NULL"
  end
end
