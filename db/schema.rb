# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_06_05_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"
  enable_extension "postgis"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "gamifications", force: :cascade do |t|
    t.string "action_key"
    t.datetime "created_at", null: false
    t.string "event_type", null: false
    t.text "log"
    t.bigint "user_id", null: false
    t.integer "value", null: false
    t.index ["action_key"], name: "index_gamifications_on_action_key"
    t.index ["event_type"], name: "index_gamifications_on_event_type"
    t.index ["user_id", "event_type"], name: "index_gamifications_on_user_id_and_event_type"
    t.index ["user_id"], name: "index_gamifications_on_user_id"
  end

  create_table "noticed_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "notifications_count"
    t.jsonb "params"
    t.bigint "record_id"
    t.string "record_type"
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id"], name: "index_noticed_events_on_record"
  end

  create_table "noticed_notifications", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "event_id", null: false
    t.datetime "read_at", precision: nil
    t.bigint "recipient_id", null: false
    t.string "recipient_type", null: false
    t.datetime "seen_at", precision: nil
    t.string "type"
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_noticed_notifications_on_event_id"
    t.index ["recipient_type", "recipient_id"], name: "index_noticed_notifications_on_recipient"
  end

  create_table "poi_categories", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.jsonb "description", default: {}
    t.string "icon"
    t.jsonb "name", default: {}, null: false
    t.integer "position", default: 0
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["position"], name: "index_poi_categories_on_position"
    t.index ["slug"], name: "index_poi_categories_on_slug", unique: true
  end

  create_table "poi_category_fields", force: :cascade do |t|
    t.boolean "active", default: true
    t.datetime "created_at", null: false
    t.string "field_key", null: false
    t.string "field_type", null: false
    t.string "hint"
    t.jsonb "label", default: {}, null: false
    t.jsonb "options", default: {}
    t.jsonb "placeholder", default: {}
    t.bigint "poi_category_id", null: false
    t.integer "position", default: 0
    t.boolean "required", default: false
    t.datetime "updated_at", null: false
    t.index ["poi_category_id", "field_key"], name: "index_poi_category_fields_on_poi_category_id_and_field_key", unique: true
    t.index ["poi_category_id"], name: "index_poi_category_fields_on_poi_category_id"
    t.index ["position"], name: "index_poi_category_fields_on_position"
  end

  create_table "pois", force: :cascade do |t|
    t.string "address"
    t.string "city"
    t.geography "coordinates", limit: {srid: 4326, type: "st_point", geographic: true}, null: false
    t.string "country"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "last_verified_at"
    t.jsonb "metadata", default: {}, null: false
    t.jsonb "name", default: {}, null: false
    t.jsonb "opening_hours", default: {}
    t.bigint "osm_id"
    t.string "phone"
    t.bigint "poi_category_id", null: false
    t.string "price_info"
    t.decimal "rating", precision: 3, scale: 2, default: "0.0"
    t.string "slug", null: false
    t.integer "status", default: 0, null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.integer "verification_count", default: 0
    t.string "website"
    t.boolean "wheelchair_accessible", default: false
    t.string "zip_code"
    t.index ["coordinates"], name: "index_pois_on_coordinates", using: :gist
    t.index ["metadata"], name: "index_pois_on_metadata", using: :gin
    t.index ["osm_id"], name: "index_pois_on_osm_id", unique: true, where: "(osm_id IS NOT NULL)"
    t.index ["poi_category_id"], name: "index_pois_on_poi_category_id"
    t.index ["slug"], name: "index_pois_on_slug", unique: true
    t.index ["status", "poi_category_id"], name: "index_pois_on_status_and_poi_category_id"
    t.index ["status"], name: "index_pois_on_status"
    t.index ["user_id"], name: "index_pois_on_user_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.bigint "resource_id"
    t.string "resource_type"
    t.datetime "updated_at", null: false
    t.index ["name", "resource_type", "resource_id"], name: "index_roles_on_name_and_resource_type_and_resource_id"
    t.index ["resource_type", "resource_id"], name: "index_roles_on_resource"
  end

  create_table "settings", force: :cascade do |t|
    t.boolean "active_user_email_enabled", default: false
    t.boolean "active_user_notifications_enabled", default: true
    t.boolean "active_user_push_enabled", default: false
    t.boolean "banned_user_email_enabled", default: false
    t.boolean "banned_user_notifications_enabled", default: true
    t.boolean "banned_user_push_enabled", default: false
    t.datetime "created_at", null: false
    t.boolean "deleted_user_email_enabled", default: false
    t.boolean "deleted_user_notifications_enabled", default: true
    t.boolean "deleted_user_push_enabled", default: false
    t.boolean "inactive_user_email_enabled", default: false
    t.boolean "inactive_user_notifications_enabled", default: true
    t.boolean "inactive_user_push_enabled", default: false
    t.boolean "new_registration_email_enabled", default: false
    t.boolean "new_registration_notifications_enabled", default: true
    t.boolean "new_registration_push_enabled", default: false
    t.boolean "pending_verification_email_enabled", default: false
    t.boolean "pending_verification_notifications_enabled", default: true
    t.boolean "pending_verification_push_enabled", default: false
    t.boolean "suspended_user_email_enabled", default: false
    t.boolean "suspended_user_notifications_enabled", default: true
    t.boolean "suspended_user_push_enabled", default: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.boolean "user_updated_by_admin_email_enabled", default: false
    t.boolean "user_updated_by_admin_notifications_enabled", default: true
    t.boolean "user_updated_by_admin_push_enabled", default: false
    t.boolean "user_updated_by_user_email_enabled", default: false
    t.boolean "user_updated_by_user_notifications_enabled", default: true
    t.boolean "user_updated_by_user_push_enabled", default: false
    t.boolean "verification_failed_email_enabled", default: false
    t.boolean "verification_failed_notifications_enabled", default: true
    t.boolean "verification_failed_push_enabled", default: false
    t.index ["user_id"], name: "index_settings_on_user_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "confirmation_sent_at"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "locked_at"
    t.string "name", default: "User", null: false
    t.string "provider"
    t.string "referral_code"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.string "slug"
    t.string "status", default: "registered"
    t.string "uid"
    t.string "unconfirmed_email"
    t.string "unlock_token"
    t.datetime "updated_at", null: false
    t.string "wallet_address"
    t.string "wallet_provider"
    t.string "wallet_provider_id"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token", unique: true
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["name"], name: "index_users_on_name"
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid", unique: true, where: "(provider IS NOT NULL)"
    t.index ["referral_code"], name: "index_users_on_referral_code", unique: true, where: "(referral_code IS NOT NULL)"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
    t.index ["status"], name: "index_users_on_status"
    t.index ["wallet_address"], name: "index_users_on_wallet_address", unique: true, where: "(wallet_address IS NOT NULL)"
  end

  create_table "users_roles", id: false, force: :cascade do |t|
    t.bigint "role_id"
    t.bigint "user_id"
    t.index ["role_id"], name: "index_users_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_users_roles_on_user_id_and_role_id"
    t.index ["user_id"], name: "index_users_roles_on_user_id"
  end

  create_table "versions", force: :cascade do |t|
    t.datetime "created_at"
    t.string "event", null: false
    t.integer "item_id", null: false
    t.string "item_type", null: false
    t.text "object"
    t.text "object_changes"
    t.integer "user_id"
    t.string "whodunnit"
    t.index ["item_type", "item_id"], name: "index_versions_on_item_type_and_item_id"
    t.index ["user_id"], name: "index_versions_on_user_id"
    t.index ["whodunnit"], name: "index_versions_on_whodunnit"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "gamifications", "users"
  add_foreign_key "poi_category_fields", "poi_categories"
  add_foreign_key "pois", "poi_categories"
  add_foreign_key "pois", "users"
  add_foreign_key "settings", "users", on_delete: :cascade
end
