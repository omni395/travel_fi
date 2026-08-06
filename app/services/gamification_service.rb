# frozen_string_literal: true

#
# GamificationService — награды токенами TFT и репутационные бейджи.
#
# ТОКЕННАЯ МОДЕЛЬ: начисления идут в user_rewards (off-chain леджер, TFT),
# а не в «баллы». Реальная отправка ERC-20 на custodial-кошелёк — через
# ContractService (контракты задеплоены, см. .env).
#
# Конфиг: config/gamification.yml (rewards — токены, badges — достижения).
#
# Использование:
#   GamificationService.award!(:registration, user)
#   GamificationService.award_referral!(referrer, new_user)
#   GamificationService.grant_badge!(user, 1)
#
class GamificationService
  class << self
    #
    # Начисляет токены TFT пользователю за действие и проверяет бейджи.
    #
    # @param action_key [String] ключ действия (registration, poi_create и т.д.)
    # @param user [User] пользователь
    # @param log [String, nil] описание начисления
    #
    def award!(action_key, user, log: nil)
      key = action_key.to_s
      amount = config.dig('rewards', key)
      return unless amount && amount.to_f.positive?

      create_reward!(user, amount, key, log || key)
      check_badges!(user, key)
    end

    #
    # Начисляет реферальные бонусы рефереру и новому пользователю.
    #
    # @param referrer [User] пользователь, чей код использовали
    # @param new_user [User] только что зарегистрированный пользователь
    #
    def award_referral!(referrer, new_user)
      award!(:referral_bonus_referrer, referrer, log: "Referred user ##{new_user.id}")
      award!(:referral_bonus_new_user, new_user, log: "Referred by ##{referrer.id}")
    end

    #
    # Создаёт запись начисления токенов (off-chain леджер).
    #
    # @param user [User] пользователь
    # @param amount [Numeric] количество токенов TFT
    # @param action_key [String] тип начисления
    # @param log [String] описание
    # @return [UserReward]
    #
    def create_reward!(user, amount, action_key, log)
      user.user_rewards.create!(
        amount: amount,
        action_key: action_key,
        log: log,
        wallet: user.wallet
      )
    end

    #
    # Возвращает ключ бейджа по его ID.
    #
    # @param badge_id [Integer] ID бейджа
    # @return [String, nil] ключ бейджа
    #
    def badge_key(badge_id)
      config.dig('badges', badge_id.to_s)&.dig('key')
    end

    #
    # Выдаёт бейдж пользователю (если ещё не выдан).
    #
    # @param user [User] пользователь
    # @param badge_id [Integer] ID бейджа
    #
    def grant_badge!(user, badge_id)
      return if user.earned_badge?(badge_id)

      user.gamifications.create!(
        event_type: 'badge',
        value: badge_id,
        action_key: badge_key(badge_id)
      )
    end

    #
    # Удаляет бейдж у пользователя.
    #
    # @param user [User] пользователь
    # @param badge_id [Integer] ID бейджа
    #
    def remove_badge!(user, badge_id)
      user.gamifications.badges.where(value: badge_id).destroy_all
    end

    #
    # Проверяет условия для всех бейджей и выдаёт подходящие.
    #
    # @param user [User] пользователь
    # @param action_key [String] ключ выполненного действия
    #
    def check_badges!(user, action_key)
      badges_config.each do |badge_id, badge|
        next if user.earned_badge?(badge_id.to_i)
        next unless badge_matches_action?(badge, action_key, user)

        grant_badge!(user, badge_id.to_i)
      end
    end

    private

    #
    # Загружает конфиг наград/бейджей из YAML.
    #
    # @return [Hash]
    #
    def config
      @config ||= YAML.safe_load_file(Rails.root.join('config/gamification.yml'))
    end

    #
    # Возвращает список бейджей из конфига.
    #
    # @return [Hash]
    #
    def badges_config
      config['badges'] || {}
    end

    #
    # Проверяет, подходит ли бейдж под выполненное действие.
    #
    # @param badge [Hash] конфиг бейджа
    # @param action_key [String] ключ действия
    # @param user [User] пользователь
    # @return [Boolean]
    #
    def badge_matches_action?(badge, action_key, user)
      condition = badge['condition']
      return false unless condition

      if condition.start_with?('action == ')
        expected_action = condition.split("'")[1]
        return action_key == expected_action
      end

      begin
        user.instance_eval(condition)
      rescue StandardError
        false
      end
    end
  end
end
