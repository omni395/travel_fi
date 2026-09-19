# frozen_string_literal: true

#
# AddCommunityModerationThresholdToSettings — глобальный порог авто-модерации
# комментариев сообществом (по голосам) для системы приложения.
#
# 1. Добавляет колонку community_moderation_threshold в таблицу settings.
# 2. Делает user_id nullable: глобальная синглтон-запись создаётся с user_id = NULL
#    (запись с настройками всего приложения, не привязанная к конкретному юзеру).
#    PostgreSQL unique-индекс index_settings_on_user_id допускает множество NULL,
#    поэтому ограничения на одну глобальную запись не возникнет.
#
class AddCommunityModerationThresholdToSettings < ActiveRecord::Migration[8.1]
  def up
    add_column :settings, :community_moderation_threshold, :integer, null: true
    change_column_null :settings, :user_id, true
  end

  def down
    change_column_null :settings, :user_id, false
    remove_column :settings, :community_moderation_threshold
  end
end
