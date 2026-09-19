# frozen_string_literal: true

#
# RecommendedPoiJob — периодический подбор и рассылка эмпирических рекомендаций.
#
# Для каждого пользователя, у которого включены рекомендации
# (Setting.recommendations_notifications_enabled И мастер-флаг notifications_enabled):
#   1. Считает «интерес» к категориям из истории просмотров (PoiView):
#        interest(category) = Σ recency_weight(poi_view) по просмотренным точкам
#      где recency_weight — экспоненциальное затухание по давности просмотра
#      (γ^days/λ). Категория с максимальным кумулятивным свежим интересом — топ.
#   2. Находит видимые (approved/imported, активных категорий) точки в топовых
#      категориях, которые пользователь ЕЩЁ не просматривал.
#   3. Ранжирует по score = recency_weight_среднее_категории × близость (ести) —
#      близкие по дате создания точки с более высоким весом интереса выше.
#   4. Рассылает до LIMIT точек через RecommendedPoiNotification (Noticed), канал
#      фильтруется по личным настройкам получателя.
#
# Расписание — config/recurring.yml (SolidQueue Recurring, каждые 6 часов).
#
class RecommendedPoiJob < ApplicationJob
  queue_as :default

  # Сколько рекомендаций максимум за один прогон на пользователя.
  LIMIT = 5

  # Период полураспада веса интереса (дни) для recency_weight.
  DECAY_DAYS = 7.0

  #
  # Выполняет генерацию и рассылку рекомендаций.
  #
  def perform
    candidates.each do |user|
      recommend_for(user)
    rescue StandardError => e
      Rails.logger.error("RecommendedPoiJob failed for user ##{user.id}: #{e.class} #{e.message}")
    end
  end

  private

  #
  # Пользователи, которым включены рекомендации (по Setting + мастер-флаг).
  #
  # @return [ActiveRecord::Relation<User>]
  #
  def candidates
    User.joins(:setting)
        .where(settings: { recommendations_notifications_enabled: true })
        .where(settings: { notifications_enabled: true })
        .distinct
  end

  #
  # Рассылает рекомендации конкретному пользователю.
  #
  # @param user [User] получатель
  #
  def recommend_for(user)
    top_pois(user).each do |poi, score|
      RecommendedPoiNotification.with(poi: poi, score: score).deliver_later(user)
    end
  end

  #
  # Возвращает до LIMIT рекомендуемых точек с их score.
  #
  # @param user [User] пользователь
  # @return [Array<Array(Poi, Float)>] пары [точка, score]
  #
  def top_pois(user)
    interest = category_interest(user)
    return [] if interest.empty?

    viewed_poi_ids = user.poi_views.pluck(:poi_id)

    # Кандидаты: видимые точки в топ-категориях интереса, ещё не просмотренные.
    candidates = Poi.visible
                    .where(poi_category_id: interest.keys)
                    .where.not(id: viewed_poi_ids)
                    .limit(LIMIT * 10) # перестраховка; далее сортируем топ-LIMIT

    scored = candidates.filter_map do |poi|
      category_weight = interest[poi.poi_category_id] || 0
      next if category_weight.zero?

      [ poi, category_weight * recency_of_creation(poi) ]
    end

    scored.sort_by { |_, score| -score }.first(LIMIT)
  end

  #
  # Кумулятивный интерес к категориям (Σ recency_weight по просмотрам).
  #
  # @param user [User] пользователь
  # @return [Hash{Integer => Float}] категория_id → суммарный вес
  #
  def category_interest(user)
    user.poi_views.ordered.includes(:poi_category).group_by(&:poi_category_id).transform_values do |views|
      views.sum { |v| v.recency_weight(decay_days: DECAY_DAYS) }
    end
  end

  #
  # Вес «свежести» точки при ранжировании: чем новее — тем выше.
  #
  # @param poi [Poi] точка
  # @return [Float] вес в (0, 1]
  #
  def recency_of_creation(poi)
    days = ((Time.current - poi.created_at) / 1.day).clamp(0.0, nil)
    (0.5 ** (days / DECAY_DAYS)).round(4)
  end
end
