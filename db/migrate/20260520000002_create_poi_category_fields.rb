# frozen_string_literal: true

#
# Миграция создания таблицы poi_category_fields
# Хранит динамические поля для каждой категории POI
# Поля создаются через админку, без миграций
#
class CreatePoiCategoryFields < ActiveRecord::Migration[8.0]
  def change
    create_table :poi_category_fields do |t|
      t.references :poi_category, null: false, foreign_key: true
      t.string :field_key, null: false               # operator_names, has_esim, fee_amount
      t.string :field_type, null: false              # string, boolean, number, select, multi_select
      t.jsonb :label, null: false, default: {}       # {"en": "Operators", "ru": "Операторы"}
      t.boolean :required, default: false
      t.jsonb :options, default: {}                  # для select: {"values": ["Vodafone","Orange"]}
      t.jsonb :placeholder, default: {}              # плейсхолдеры по локалям
      t.string :hint                                 # подсказка при вводе
      t.integer :position, default: 0
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :poi_category_fields, [ :poi_category_id, :field_key ], unique: true
    add_index :poi_category_fields, :position
  end
end
