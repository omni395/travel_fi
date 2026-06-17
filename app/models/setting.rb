# frozen_string_literal: true

#
# Settings модель - настройки уведомлений пользователя
#
# Поля в БД имеют префиксы по типу события (new_registration_*, user_updated_by_user_* и т.д.)
# Для user-facing настроек используем алиас profile_updated_* → user_updated_by_user_*
#
class Setting < ApplicationRecord
  # PaperTrail - аудит всех изменений настроек
  has_paper_trail

  belongs_to :user

  # Валидации
  validates :user_id, presence: true, uniqueness: true

  # Алиасы для user-facing полей (profile_updated → user_updated_by_user)
  alias_attribute :profile_updated_notifications_enabled, :user_updated_by_user_notifications_enabled
  alias_attribute :profile_updated_email_enabled, :user_updated_by_user_email_enabled
  alias_attribute :profile_updated_push_enabled, :user_updated_by_user_push_enabled

  #
  # Создает настройки по умолчанию после создания пользователя
  # Вызывается автоматически. Идемпотентно — повторный вызов не падает.
  #
  def self.create_for_user(user)
    find_or_create_by!(user: user)
  end
end
