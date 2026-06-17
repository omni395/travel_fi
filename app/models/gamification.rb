# frozen_string_literal: true

#
# Gamification — единая модель для баллов и бейджей пользователя.
#
# event_type: "score" — начисление баллов, value = количество баллов
# event_type: "badge" — выдача бейджа, value = badge_id
#
# Использование:
#   Gamification.scores  — только баллы
#   Gamification.badges  — только бейджи
#
class Gamification < ApplicationRecord
  belongs_to :user

  scope :scores, -> { where(event_type: "score") }
  scope :badges, -> { where(event_type: "badge") }
  scope :ordered, -> { order(created_at: :desc) }
end
