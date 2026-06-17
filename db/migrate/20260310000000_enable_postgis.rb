# frozen_string_literal: true

#
# Миграция включения PostGIS расширения
# Выполняется первой, чтобы все последующие миграции могли использовать PostGIS типы
#
class EnablePostgis < ActiveRecord::Migration[8.0]
  def change
    enable_extension "postgis" unless extension_enabled?("postgis")
  end
end
