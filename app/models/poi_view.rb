# frozen_string_literal: true

#
# PoiView — фиксация просмотра карточки POI пользователем.
#
# Используется для эмпирических рекомендаций: накопительная статистика
# «какие категории точек пользователь просматривает». При повторном просмотре
# той же точки запись НЕ плодится — обновляется viewed_at (unique index
# user_id + poi_id), что даёт вес по свежести.
#
# poi_category_id денормализован (дублирует poi.poi_category_id) — чтобы
# агрегировать интерес по категории без join на POI при формировании
# рекомендаций.
#
class PoiView < ApplicationRecord
  # Аудит всех просмотров.
  has_paper_trail

  belongs_to :user
  belongs_to :poi
  belongs_to :poi_category

  # Валидации: одна запись «пользователь + точка» (дублирует unique index).
  validates :user_id, uniqueness: { scope: :poi_id }
  validates :viewed_at, presence: true

  # Скоупы
  scope :ordered, -> { order(viewed_at: :desc) }

  #
  # Возвращает вес просмотра с экспоненциальным затуханием по давности.
  #
  # @param decay_days [Float] период полураспада в днях (γ = 0.5)
  # @return [Float] вес в диапазоне (0, 1]
  #
  def recency_weight(decay_days: 7.0)
    days_ago = ((Time.current - viewed_at) / 1.day).clamp(0.0, nil)
    (0.5 ** (days_ago / decay_days)).round(4)
  end
end
