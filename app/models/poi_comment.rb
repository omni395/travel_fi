# frozen_string_literal: true

#
# PoiComment — комментарий к точке интереса (POI)
#
# Поддерживает threaded-структуру через parent_id (self-join):
#   - parent_id == nil  → корневой комментарий
#   - parent_id != nil  → ответ на корневой (1 уровень вложенности)
#
# @attr poi_id     [Integer] ссылка на POI
# @attr user_id    [Integer] автор комментария
# @attr parent_id  [Integer, nil] родительский комментарий (опционально)
# @attr body       [Text] текст комментария
#
class PoiComment < ApplicationRecord
  # Аудит всех изменений
  has_paper_trail

  # Ассоциации
  belongs_to :poi, touch: true
  belongs_to :user
  belongs_to :parent, class_name: "PoiComment", optional: true

  # Голоса сообщества (Vote, полиморфный votable)
  has_many :votes, as: :votable, dependent: :destroy

  # Валидации
  validates :body, presence: true, length: { minimum: 2, maximum: 1000 }

  # Скоупы
  scope :recent, -> { order(created_at: :desc) }
  scope :roots, -> { where(parent_id: nil) }
  scope :replies_for, ->(comment_id) { where(parent_id: comment_id) }
end
