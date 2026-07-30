# frozen_string_literal: true

#
# Создание таблицы poi_comments для threaded комментариев к POI
# parent_id: nullable self-join для ответов (1 уровень вложенности)
#
class CreatePoiComments < ActiveRecord::Migration[8.1]
  def change
    create_table :poi_comments do |t|
      t.references :poi, null: false, foreign_key: { on_delete: :cascade }
      t.references :user, null: false, foreign_key: { on_delete: :cascade }
      t.references :parent, foreign_key: { to_table: :poi_comments, on_delete: :cascade }
      t.text :body, null: false
      t.timestamps
    end

    add_index :poi_comments, :created_at
    add_index :poi_comments, [ :poi_id, :created_at ], name: "idx_poi_comments_on_poi_and_created"
  end
end
