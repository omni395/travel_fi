# frozen_string_literal: true

#
# TokenTransaction — журнал движения токенов TFT пользователя.
#
# Каждое начисление (UserReward, off-chain леджер) фиксируется записью с
# direction = credit в единой транзакции. Поле tx_hash остаётся пустым до
# on-chain отправки через релей (EIP-2771); после отправки сюда записывается
# хэш транзакции в сети, по которому строится ссылка на explorer.
#
# direction: credit (приход) / debit (расход — будущий Token Spend)
# status:    pending (начислено off-chain, on-chain не отправлено)
#            confirmed (tx_hash заполнен)
#            failed (on-chain отправка упала)
#
# Лок-модель (vesting на бэке):
#   claimed (boolean) — маркер «получено/забрано».
#     false → начисление не забрано (ждёт разблокировки по lock-периоду);
#     true  → получено (on-chain отправлено через relay).
#   Лок-период НЕ хранится: разблокировка = `updated_at + lock_days` уже
#   наступило. Мгновенные начисления (registration / referral_*) имеют lock=0
#   и сразу помечаются claimed=true после relay.
#
class TokenTransaction < ApplicationRecord
  # Action-ключи с нулевым лок-периодом (начисление сразу доступно для траты):
  # welcome-токены за регистрацию и бонус самому новому юзеру. Реферальный бонус
  # РЕФЕРЕРА (referral_bonus_referrer) НАМЕРЕННО не входит в этот список — он
  # становится available по vesting-лок-периоду (антифрод: реферер получает
  # on-chain токены только после квалификации/разблокировки, а не мгновенно).
  INSTANT_ACTION_KEYS = %w[registration referral_bonus_new_user].freeze
  # Аудит всех изменений транзакций.
  has_paper_trail

  belongs_to :user
  belongs_to :wallet, optional: true
  belongs_to :user_reward, optional: true

  enum :direction, {
    credit: "credit",
    debit: "debit"
  }, validate: true

  enum :status, {
    pending: "pending",
    confirmed: "confirmed",
    failed: "failed"
  }, validate: true

  validates :amount, numericality: { greater_than: 0 }
  validates :action_key, presence: true
  validates :chain_id, presence: true

  scope :ordered, -> { order(created_at: :desc) }

  # Незабранные начисления (claimed = false).
  scope :unclaimed, -> { where(claimed: false) }

  # Разблокированные по лок-периоду и ещё не забранные начисления.
  # Считается на лету по `updated_at + lock_days` — без отдельного поля.
  #
  # @param lock_days [Integer] лок-период в днях (по умолчанию pool.lock_days)
  #
  scope :available, ->(lock_days: nil) {
    cutoff = lock_days ? lock_days.to_i.days.ago : default_lock_cutoff
    unclaimed.where(created_at: ..cutoff)
  }

  # Заблокированные по лок-периоду (ещё не разблокированы) начисления.
  #
  # @param lock_days [Integer] лок-период в днях (по умолчанию pool.lock_days)
  #
  scope :locked, ->(lock_days: nil) {
    cutoff = lock_days ? lock_days.to_i.days.ago : default_lock_cutoff
    unclaimed.where(created_at: cutoff..)
  }

  class << self
    #
    # Граница лок-периода по умолчанию: `pool.lock_days` дней назад.
    #
    # @return [ActiveSupport::TimeWithZone] дата-граница
    #
    def default_lock_cutoff
      lock_days = GamificationService.pool_lock_days
      lock_days.days.ago
    end
  end

  #
  # Возвращает «выжимку» on-chain хэша для отображения: 4 первых + 4 последних символа.
  #
  # @return [String, nil] выжимка хэша (например "0x1234...5678") или nil
  #
  def short_hash
    return nil if tx_hash.blank?

    "#{tx_hash[0, 4]}...#{tx_hash[-4, 4]}"
  end

  #
  # Возвращает полный URL транзакции в block explorer (из ENV CHAIN_EXPLORER_URL).
  #
  # @return [String, nil] URL вида "https://.../tx/0x..." или nil
  #
  def explorer_url
    return nil if tx_hash.blank?

    base = ENV["CHAIN_EXPLORER_URL"]
    return nil if base.blank?

    "#{base.sub(%r{/+\z}, '')}/tx/#{tx_hash}"
  end

  #
  # Мгновенное ли начисление (lock=0): registration / referral_*.
  #
  # @return [Boolean] true — без лок-периода
  #
  def instant?
    INSTANT_ACTION_KEYS.include?(action_key)
  end

  #
  # Лок-период начисления в днях.
  # Мгновенные (registration/referral_*) = 0; остальные — pool.lock_days.
  #
  # @return [Integer] лок-период в днях
  #
  def lock_days
    instant? ? 0 : GamificationService.pool_lock_days
  end

  #
  # Начисление ещё заблокировано (не прошёл лок-период) и не забрано.
  #
  # @return [Boolean]
  #
  def locked?
    !instant? && !claimed? && created_at > lock_days.days.ago
  end

  #
  # Начисление разблокировано по лок-периоду, ещё не забрано и отправлено.
  # Мгновенные (lock=0) доступны сразу.
  #
  # @return [Boolean]
  #
  def available?
    !claimed? && created_at <= lock_days.days.ago
  end
end
