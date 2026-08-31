# frozen_string_literal: true

#
# Vote — голос сообщества за контент (POI, Photo, PoiComment).
#
# Единая полиморфная модель: votable — любая голосуемая сущность. Один юзер
# может голосовать за конкретную сущность ТОЛЬКО один раз (unique index
# [votable_type, votable_id, user_id]); повторное голосование = toggle value
# (+1 апрув / -1 дизлайк), число уникальных голосов не растёт.
#
# Голоса НЕ меняют статус POI и НЕ влияют на видимость — только вешают бейджи
# «Одобрено/Отклонено сообществом» (см. ModerationService). Каждый голос
# трекается PaperTrail (честный аудит — догма Database-Triggered Workflow).
#
# @attr votable [Poi, Photo, PoiComment] голосуемая сущность (полиморфная)
# @attr user [User] автор голоса
# @attr value [Integer] +1 (апрув) / -1 (дизлайк)
#
class Vote < ApplicationRecord
  # Аудит каждого голоса (догма: PaperTrail — Single Source of Truth)
  has_paper_trail

  # Ассоциации
  belongs_to :votable, polymorphic: true
  belongs_to :user

  # Валидации
  validates :value, inclusion: { in: [ 1, -1 ], message: I18n.t("activerecord.errors.models.vote.attributes.value.inclusion") }
  # Один юзер = один голос за конкретную сущность (дублирует unique index в БД).
  validates :user_id, uniqueness: { scope: [ :votable_type, :votable_id ] }

  # Скоупы
  scope :ups, -> { where(value: 1) }
  scope :downs, -> { where(value: -1) }

  #
  # Голосовал ли пользователь за эту сущность (любым значением).
  #
  # @return [Boolean]
  #
  def self.voted_by?(user)
    exists?(user: user)
  end
end
