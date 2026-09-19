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

  # Мастер-флаги — глобальный выключатель всех каналов (primary фильтр в нотификациях)
  NOTIFICATIONS_CHANNELS = %i[notifications email push].freeze

  # Юзер-события, для которых есть колонки вида <event>_<channel>_enabled.
  USER_EVENTS = %w[
    profile_updated my_poi_status my_poi_comment my_poi_photo
    reward_available reward_locked badge_earned recommendations
  ].freeze

  # Админ-события.
  ADMIN_EVENTS = %w[
    new_registration user_updated_by_admin osm_import
    pending_moderation community_rejected system_alert
  ].freeze

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

  # Дефолтная геймификация (rewards + pool + badges) — используется, пока админ
  # не сохранил свою конфигурацию. Источник правды после первого сохранения —
  # gamification_config (JSONB) глобальной синглтон-записи. Все значения
  # подхватываются на лету без редеплоя.
  GAMIFICATION_DEFAULTS = {
    "rewards" => {
      "registration" => 10,
      "referral_bonus_referrer" => 15,
      "referral_bonus_new_user" => 5,
      "poi_create" => 10,
      "poi_photo_add" => 3,
      "comment_create" => 3,
      "poi_vote" => 1
    },
    "pool" => {
      "lock_days" => 7,
      "warning_balance" => 10_000_000,
      "critical_balance" => 1_000_000
    },
    "badges" => {
      "1" => { "key" => "registration_complete", "name" => "Registration Complete", "icon" => "mdi-account-check", "condition" => "action == 'users#create'" },
      "2" => { "key" => "first_poi", "name" => "First POI", "icon" => "mdi-map-marker-star", "condition" => "user.pois.count == 1" },
      "3" => { "key" => "contributor", "name" => "Contributor", "icon" => "mdi-star-face", "condition" => "user.pois.count >= 10" },
      "4" => { "key" => "explorer", "name" => "Explorer", "icon" => "mdi-compass", "condition" => "user.poi_cities_count >= 5" },
      "5" => { "key" => "recruiter", "name" => "Recruiter", "icon" => "mdi-account-group", "condition" => "user.referrals_count >= 5" },
      "6" => { "key" => "veteran", "name" => "Veteran", "icon" => "mdi-shield-star", "condition" => "user.token_balance >= 1000" }
    }
  }.freeze

  #
  # Глобальная конфигурация геймификации (rewards + pool + badges).
  # Берётся из gamification_config глобальной синглтон-записи. Если ещё не
  # заполнена (до первого сохранения админом) — возвращает дефолты.
  #
  # @return [Hash] { "rewards" => {...}, "pool" => {...}, "badges" => {...} }
  #
  def self.gamification_config
    global_settings.gamification_config.presence || GAMIFICATION_DEFAULTS.deep_dup
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
