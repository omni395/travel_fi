# frozen_string_literal: true

#
# Миграция добавляет поле source в таблицу pois
# для разделения точек, загруженных из OSM и созданных вручную
#
class AddSourceToPois < ActiveRecord::Migration[8.1]
  def change
    add_column :pois, :source, :string, null: false, default: "manual"
    add_index :pois, :source
  end
end
