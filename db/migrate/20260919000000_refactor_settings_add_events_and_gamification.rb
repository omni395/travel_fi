# frozen_string_literal: true

#
# RefactorSettingsAddEventsAndGamification — расширение секции настроек.
#
# 1. Мастер-флаги: глобальный выключатель всех каналов для пользователя
#    (notifications_enabled / email_enabled / push_enabled). Используются
#    уведомлениями как первичный фильтр (AND с событием-флагом).
#
# 2. Юзер-события (каждое × notifications/email/push):
#    - my_poi_status   — моя точка одобрена / отклонена / изменена
#    - my_poi_comment  — новый комментарий/ответ к моей точке
#    - my_poi_photo    — добавлено фото к моей точке
#    - reward_available— токены разблокированы (можно забрать / claim)
#    - reward_locked   — токены начислены, но заблокированы лок-периодом
#    - badge_earned    — получена ачивка (бейдж)
#    - recommendations — эмпирические POI по интересам (PoiView)
#
# 3. Админ-события (каждое × notifications/email/push):
#    - new_registration, user_updated_by_admin, osm_import (уже есть)
#    - pending_moderation — новая/изменённая точка со статусом pending
#    - community_rejected — точка получила бейдж «Отклонено сообществом»
#    - system_alert       — системные алерты (баланс пула ContractBalance)
#
# 4. gamification_config (JSONB) — перенос геймификации (rewards + pool + badges)
#    из config/gamification.yml в глобальную синглтон-запись Setting (user_id=NULL).
#    Значения подхватываются на лету без редеплоя: GamificationService читает
#    из Setting.global_settings.gamification_config, а не из YAML.
#
class RefactorSettingsAddEventsAndGamification < ActiveRecord::Migration[8.1]
  # Юзер-события, для которых добавляем набор из 3 колонок.
  USER_EVENTS = %w[
    my_poi_status my_poi_comment my_poi_photo
    reward_available reward_locked badge_earned recommendations
  ].freeze

  # Админ-события, для которых добавляем набор из 3 колонок.
  ADMIN_EVENTS = %w[
    pending_moderation community_rejected system_alert
  ].freeze

  def change
    change_table :settings do |t|
      # Мастер-флаги
      t.boolean :notifications_enabled, default: true
      t.boolean :email_enabled, default: true
      t.boolean :push_enabled, default: true

      # Юзер-события
      USER_EVENTS.each do |event|
        t.boolean "#{event}_notifications_enabled", default: true
        t.boolean "#{event}_email_enabled", default: false
        t.boolean "#{event}_push_enabled", default: false
      end

      # Админ-события
      ADMIN_EVENTS.each do |event|
        t.boolean "#{event}_notifications_enabled", default: true
        t.boolean "#{event}_email_enabled", default: false
        t.boolean "#{event}_push_enabled", default: false
      end

      # Геймификация (rewards + pool + badges) для Setting.global
      t.jsonb :gamification_config, null: true
    end

    # Таблица просмотров POI для эмпирических рекомендаций.
    create_table :poi_views do |t|
      t.references :user, null: false, foreign_key: true
      t.references :poi, null: false, foreign_key: true
      t.references :poi_category, null: false, foreign_key: true
      t.datetime :viewed_at, null: false, default: -> { "CURRENT_TIMESTAMP" }

      t.timestamps

      t.index %i[user_id poi_id], unique: true
      t.index %i[user_id poi_category_id]
    end
  end
end
