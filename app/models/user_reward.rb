# frozen_string_literal: true

#
# UserReward — off-chain начисление токенов TFT пользователю.
#
# amount — количество токенов (TFT, decimals 18), action_key — тип начисления
# (registration, referral_bonus_*, poi_create и т.д.). On-chain отправка на кошелёк —
# через TokenTransactionService.relay! (контракты уже задеплоены, см. .env).
#
class UserReward < ApplicationRecord
  # Аудит всех начислений (догма: PaperTrail — Single Source of Truth).
  has_paper_trail

  belongs_to :user
  belongs_to :wallet, optional: true

  # Источник начисления (Poi / Photo / PoiComment / Vote) — реляционная
  # полиморфная связь. Нужна для точечного отзыва (revoke! по source) и
  # UI-резолва «за что начислено». Сама колонка аудируется (модель has_paper_trail).
  belongs_to :source, polymorphic: true, optional: true

  validates :amount, numericality: { greater_than: 0 }
  validates :action_key, presence: true
end
