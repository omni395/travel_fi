# frozen_string_literal: true

#
# Миграция создания таблицы poi_categories
# Хранит категории POI (SIM/eSIM, туалеты, вода и т.д.)
# Категории создаются через админку, без enum
#
class CreatePoiCategories < ActiveRecord::Migration[8.0]
  def change
    create_table :poi_categories do |t|
      t.jsonb :name, null: false, default: {}       # {"en": "SIM/eSIM", "ru": "Сим-карты"}
      t.string :slug, null: false                    # sim_esim
      t.string :icon                                 # mdi-sim (комментарий: иконка MDI)
      t.jsonb :description, default: {}              # многоязычное описание
      t.integer :position, default: 0                # порядок сортировки
      t.boolean :active, default: true
      t.timestamps
    end

    add_index :poi_categories, :slug, unique: true
    add_index :poi_categories, :position
  end
end
