# frozen_string_literal: true

#
# GamificationService — награды токенами TFT и репутационные бейджи.
#
# ТОКЕННАЯ МОДЕЛЬ: начисления идут в user_rewards (off-chain леджер, TFT),
# а не в «баллы». Реальная отправка ERC-20 на custodial-кошелёк — через
# TokenTransactionService.relay! (контракты задеплоены, см. .env).
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
      amount = config.dig("rewards", key)
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
    # Отзывает НЕ забранные начисления токенов TFT за действие.
    #
    # Применяется, когда стало ясно, что награда не заслужена (например, удалили
    # фото POI до того, как оно прошло верификацию/лок-период). Отзывается ТОЛЬКО
    # не забранное (claimed=false) начисление — on-chain ещё не отправлен (relay
    # для vesting-ключей не ставился). Уже забранное (claimed=true / on-chain в
    # сети) на бэке отозвать нельзя → НЕ трогается, возвращает 0.
    #
    # Удаляет пару "UserReward + TokenTransaction" атомарно (чистит начисления из
    # off-chain леджера и связанный журнал). `destroy` создаёт PaperTrail-версии —
    # честный аудит отзыва. Идемпотентен: повторный вызов при отсутствии
    # начислений → 0, без ошибки.
    #
    # @param action_key [String, Symbol] ключ действия (poi_photo_add и т.д.)
    # @param user [User] пользователь, чьё начисление отзываем
    # @return [Integer] количество отозванных начислений
    #
    def revoke!(action_key, user)
      key = action_key.to_s
      transactions = user.token_transactions.where(action_key: key, claimed: false)

      revoked = 0
      ActiveRecord::Base.transaction do
        transactions.each do |tx|
          begin
            reward = tx.user_reward
            tx.destroy!
            reward&.destroy!
            revoked += 1
          rescue StandardError => e
            # Сбой отзыва одной записи не роняет остальные.
            Rails.logger.error("GamificationService revoke! failed for TX ##{tx&.id}: #{e.class} #{e.message}")
          end
        end
      end
      revoked
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
      # Единая транзакция: off-chain начисление (UserReward) + запись журнала
      # движения токенов (TokenTransaction). Всё или ничего.
      ActiveRecord::Base.transaction do
        reward = user.user_rewards.create!(
          amount: amount,
          action_key: action_key,
          log: log,
          wallet: user.wallet
        )

        create_token_transaction!(reward)
        reward
      end
    end

    #
    # Создаёт запись журнала движения токенов (TokenTransaction) для начисления.
    # tx_hash пустой до on-chain отправки через релей (EIP-2771); статус pending.
    #
    # Лок-модель:
    #   - мгновенные начисления (registration / referral_*) → claimed=false, но
    #     relay-Джоб ставим СРАЗУ (lock=0, токены доступны для траты);
    #   - vesting-начисления (остальные) → claimed=false, relay НЕ ставим —
    #     отправка произойдёт через claim (UserService.claim_rewards!).
    #
    # @param reward [UserReward] только что созданное начисление
    # @return [TokenTransaction]
    #
    def create_token_transaction!(reward)
      transaction = reward.user.token_transactions.create!(
        amount: reward.amount,
        direction: :credit,
        action_key: reward.action_key,
        status: :pending,
        claimed: false,
        chain_id: default_chain_id,
        metadata: { log: reward.log },
        wallet: reward.wallet,
        user_reward: reward
      )

      # Мгновенные (lock=0) уходят в очередь сразу; vesting — только по claim.
      enqueue_relay(transaction) if transaction.instant?
      transaction
    end

    #
    # Ставит on-chain отправку начисления в очередь (SolidQueue).
    # Сбой очереди не роняет начисление (остаётся pending для backfill).
    #
    # @param transaction [TokenTransaction] запись журнала токенов
    #
    def enqueue_relay(transaction)
      TokenTransactionRelayJob.perform_later(transaction.id)
    rescue StandardError => e
      Rails.logger.error("Failed to enqueue TokenTransactionRelayJob: #{e.class} #{e.message}")
    end

    #
    # Возвращает id сети по умолчанию из ENV (CHAIN_ID, например 0x14a34 → 84532).
    #
    # @return [String] id сети
    #
    def default_chain_id
      (ENV["CHAIN_ID"] || "0x14a34").to_i(16).to_s
    end

    #
    # Возвращает ключ бейджа по его ID.
    #
    # @param badge_id [Integer] ID бейджа
    # @return [String, nil] ключ бейджа
    #
    def badge_key(badge_id)
      config.dig("badges", badge_id.to_s)&.dig("key")
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
        event_type: "badge",
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

    #
    # Секция pool глобальной конфигурации (config/gamification.yml).
    #
    # @return [Hash] { lock_days:, warning_balance:, critical_balance: }
    #
    def pool_config
      config["pool"] || {}
    end

    #
    # Лок-период начислений (дни) из конфигурации pool.
    #
    # @return [Integer] по умолчанию 7
    #
    def pool_lock_days
      (pool_config["lock_days"] || 7).to_i
    end

    #
    # Порог «жёлтой» плашки баланса pool (TFT).
    #
    # @return [Integer] по умолчанию 10_000_000
    #
    def pool_warning_balance
      (pool_config["warning_balance"] || 10_000_000).to_i
    end

    #
    # Порог «красной» плашки баланса pool (TFT).
    #
    # @return [Integer] по умолчанию 1_000_000
    #
    def pool_critical_balance
      (pool_config["critical_balance"] || 1_000_000).to_i
    end

    private

    #
    # Загружает конфиг наград/бейджей из YAML.
    #
    # @return [Hash]
    #
    def config
      @config ||= YAML.safe_load_file(Rails.root.join("config/gamification.yml"))
    end

    #
    # Возвращает список бейджей из конфига.
    #
    # @return [Hash]
    #
    def badges_config
      config["badges"] || {}
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
      condition = badge["condition"]
      return false unless condition

      if condition.start_with?("action == ")
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
