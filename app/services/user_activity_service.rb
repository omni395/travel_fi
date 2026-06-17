# frozen_string_literal: true

#
# UserActivityService — сервис для сбора активности пользователя из Gamification
#
# Собирает данные из таблицы gamifications:
# - event_type: "badge" — полученные бейджи
# - event_type: "score" — начисленные баллы
#
# Возвращает отсортированный по времени массив событий ActivityEvent
#
class UserActivityService
  ActivityEvent = Struct.new(:type, :title, :description, :created_at, :icon, :color, keyword_init: true)

  #
  # Инициализирует сервис
  #
  # @param user [User] пользователь, для которого собирается активность
  #
  def initialize(user:)
    @user = user
  end

  #
  # Собирает и возвращает все события активности пользователя
  #
  # @return [Array<ActivityEvent>] отсортированный по created_at (DESC) массив событий
  #
  def call
    events = []
    events.concat(badge_events)
    events.concat(score_events)
    events.sort_by(&:created_at).reverse
  end

  private

  attr_reader :user

  #
  # Формирует события из полученных бейджей
  #
  # @return [Array<ActivityEvent>]
  #
  def badge_events
    user.gamifications.badges.ordered.map do |g|
      ActivityEvent.new(
        type: :badge,
        title: t("gamification.badges.#{g.action_key}.title", default: "Badge ##{g.value}"),
        description: t("gamification.badges.#{g.action_key}.description", default: ""),
        created_at: g.created_at,
        icon: badge_icon(g.action_key),
        color: "text-yellow-500"
      )
    end
  end

  #
  # Формирует события из начисленных баллов
  #
  # @return [Array<ActivityEvent>]
  #
  def score_events
    user.gamifications.scores.ordered.map do |g|
      ActivityEvent.new(
        type: :score,
        title: t("admin.users.activity.points_earned", points: g.value),
        description: g.log.presence || t("admin.users.activity.points_earned_desc"),
        created_at: g.created_at,
        icon: "mdi-star",
        color: "text-blue-500"
      )
    end
  end

  #
  # Возвращает иконку для бейджа по его ключу
  #
  # @param action_key [String, nil] ключ бейджа
  # @return [String] класс MDI иконки
  #
  def badge_icon(action_key)
    case action_key
    when "registration_complete" then "mdi-account-check"
    when "first_poi" then "mdi-map-marker-star"
    when "contributor" then "mdi-star-face"
    when "explorer" then "mdi-compass"
    when "recruiter" then "mdi-account-group"
    when "veteran" then "mdi-shield-star"
    else "mdi-trophy"
    end
  end

  #
  # Хелпер для I18n переводов
  #
  # @param key [String] ключ перевода
  # @param opts [Hash] опции
  # @return [String]
  #
  def t(key, **opts)
    I18n.t(key, **opts)
  end
end
