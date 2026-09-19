# frozen_string_literal: true

#
# Admin::GamificationSettingsComponent — форма настройки геймификации админом.
#
# Отображает числовые значения rewards (награды TFT за действия) и
# pool (lock_days, warning/critical_balance). Изменение отправляется через
# StimulusReflex (Admin::GamificationSettingsReflex) → SettingService.
# gamification_config (JSONB) обновляется на лету без редеплоя.
#
# @param config [Hash] Setting.gamification_config (rewards + pool + badges)
#
class Admin::GamificationSettingsComponent < ApplicationComponent
  # Разрешённые ключи rewards (из дефолтной конфигурации).
  REWARD_KEYS = %w[
    registration referral_bonus_referrer referral_bonus_new_user
    poi_create poi_photo_add comment_create poi_vote
  ].freeze

  # Числовые ключи секции pool.
  POOL_KEYS = %w[lock_days warning_balance critical_balance].freeze

  def initialize(config:)
    @config = config || {}
    @config = @config.with_indifferent_access
  end

  private

  attr_reader :config

  #
  # Значение reward по ключу.
  #
  # @param key [String] ключ награды
  # @return [Integer]
  #
  def reward_value(key)
    config.dig(:rewards, key).to_i
  end

  #
  # Значение pool по ключу.
  #
  # @param key [String] ключ pool
  # @return [Integer]
  #
  def pool_value(key)
    config.dig(:pool, key).to_i
  end
end
