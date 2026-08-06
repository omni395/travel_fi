# frozen_string_literal: true

#
# Добавляет настройки уведомлений для события OSM-импорта в таблицу settings.
# Паттерн совпадает с остальными событиями (new_registration_*, active_user_* и т.д.):
#   in-app (notifications) — default true, email/push — default false.
#
class AddOsmImportToSettings < ActiveRecord::Migration[8.1]
  def change
    add_column :settings, :osm_import_notifications_enabled, :boolean, default: true
    add_column :settings, :osm_import_email_enabled, :boolean, default: false
    add_column :settings, :osm_import_push_enabled, :boolean, default: false
  end
end
