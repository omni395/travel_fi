# frozen_string_literal: true

#
# Создаёт таблицу gamifications — единое хранилище баллов и бейджей.
# Заменяет 6 таблиц гема Merit.
#
class CreateGamifications < ActiveRecord::Migration[8.1]
  def change
    create_table :gamifications do |t|
      t.references :user, null: false, foreign_key: true
      t.string :event_type, null: false  # "score" | "badge"
      t.integer :value, null: false      # баллы или badge_id
      t.string :action_key               # "registration", "first_poi" и т.д.
      t.text :log                        # описание начисления

      t.datetime :created_at, null: false
    end

    add_index :gamifications, :event_type
    add_index :gamifications, :action_key
    add_index :gamifications, [ :user_id, :event_type ]
  end
end
