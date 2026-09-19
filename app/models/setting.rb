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

  # user может быть nil для глобальной синглтон-записи настроек приложения
  # (см. .global_settings / .global_threshold).
  belongs_to :user, optional: true

  # Валидации: user_id не обязателен (nullable для глобальной записи);
  # уникальность — только для привязанных к пользователю записей.
  validates :user_id, presence: true, uniqueness: true, if: -> { user_id.present? }

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

  #
  # Глобальная синглтон-запись настроек приложения (user_id = NULL).
  # Содержит общие настройки, не привязанные к конкретному пользователю.
  # Идемпотентно — повторный вызов не создаёт дубль (NULL не конфликтует
  # с unique-индексом user_id).
  #
  # @return [Setting]
  #
  def self.global_settings
    find_or_create_by!(user_id: nil)
  end

  #
  # Глобальный порог авто-модерации комментариев (по голосам сообщества).
  # Берётся из community_moderation_threshold глобальной синглтон-записи;
  # при отсутствии значения — дефолт (10).
  #
  # @return [Integer]
  #
  def self.global_threshold
    global_settings.community_moderation_threshold || 10
  end
end
