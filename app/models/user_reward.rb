# frozen_string_literal: true

#
# UserReward — off-chain начисление токенов TFT пользователю.
#
# amount — количество токенов (TFT, decimals 18), action_key — тип начисления
# (registration, referral_bonus_*, poi_create и т.д.). On-chain отправка на кошелёк —
# через TokenTransactionService.relay! (контракты уже задеплоены, см. .env).
#
class UserReward < ApplicationRecord
  # Аудит всех начислений.
  has_paper_trail

  belongs_to :user
  belongs_to :wallet, optional: true

  validates :amount, numericality: { greater_than: 0 }
  validates :action_key, presence: true
end
