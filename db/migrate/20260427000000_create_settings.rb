# frozen_string_literal: true

class CreateSettings < ActiveRecord::Migration[8.1]
  def change
    create_table :settings do |t|
      t.references :user, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }

      # ==========================================
      # USER REGISTRATION & STATUS CHANGES
      # ==========================================
      t.boolean :new_registration_notifications_enabled, default: true
      t.boolean :new_registration_push_enabled, default: false
      t.boolean :new_registration_email_enabled, default: false

      t.boolean :inactive_user_notifications_enabled, default: true
      t.boolean :inactive_user_push_enabled, default: false
      t.boolean :inactive_user_email_enabled, default: false

      t.boolean :pending_verification_notifications_enabled, default: true
      t.boolean :pending_verification_push_enabled, default: false
      t.boolean :pending_verification_email_enabled, default: false

      t.boolean :verification_failed_notifications_enabled, default: true
      t.boolean :verification_failed_push_enabled, default: false
      t.boolean :verification_failed_email_enabled, default: false

      t.boolean :active_user_notifications_enabled, default: true
      t.boolean :active_user_push_enabled, default: false
      t.boolean :active_user_email_enabled, default: false

      t.boolean :suspended_user_notifications_enabled, default: true
      t.boolean :suspended_user_push_enabled, default: false
      t.boolean :suspended_user_email_enabled, default: false

      t.boolean :banned_user_notifications_enabled, default: true
      t.boolean :banned_user_push_enabled, default: false
      t.boolean :banned_user_email_enabled, default: false

      t.boolean :deleted_user_notifications_enabled, default: true
      t.boolean :deleted_user_push_enabled, default: false
      t.boolean :deleted_user_email_enabled, default: false

      # ==========================================
      # USER PROFILE UPDATES
      # ==========================================
      t.boolean :user_updated_by_admin_notifications_enabled, default: true
      t.boolean :user_updated_by_admin_push_enabled, default: false
      t.boolean :user_updated_by_admin_email_enabled, default: false

      t.boolean :user_updated_by_user_notifications_enabled, default: true
      t.boolean :user_updated_by_user_push_enabled, default: false
      t.boolean :user_updated_by_user_email_enabled, default: false

      t.timestamps
    end
  end
end
