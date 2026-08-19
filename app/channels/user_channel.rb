# frozen_string_literal: true

#
# UserChannel - канал пользовательской части приложения
#
# Модель «2 канала с адресными стримами» (см. README «Канальная модель»):
# один класс канала подписывает клиента на НЕСКОЛЬКО стримов, а серверные
# бродкастеры адресуют сообщение по имени стрима.
#
# Подписки (стримы), которые получает пользователь через этот канал:
#   - "user_#{id}"  — ПЕРСОНАЛЬНЫЙ поток (профиль, свои тосты, ответы на его
#                     комментарии, статус его точки). Разрешает вопрос
#                     «как вычленить конкретного пользователя из общего потока».
#   - "pois_map"    — ОБЩИЙ поток карты (poi:reload-features, live-обновление
#                     маркеров/списка для ВСЕХ пользователей на карте). Каждый
#                     клиент сам фильтрует по видимым границам (_detailIntersectsView).
#
# Noticed-уведомления (channel: "UserChannel", stream: :user_stream → "user_N")
# доставляются в персональный стрим и совпадают с этой подпиской.
#
class UserChannel < ActionCable::Channel::Base
  include CableReady::Broadcaster

  #
  # Подписывает аутентифицированного пользователя на персональный и общий потоки
  #
  def subscribed
    return reject unless current_user

    stream_from "user_#{current_user.id}"
    stream_from "pois_map"

    Rails.logger.info("UserChannel: User #{current_user.id} subscribed to user_#{current_user.id} + pois_map")
  rescue StandardError => e
    Rails.logger.error("UserChannel subscription error: #{e.class} #{e.message}")
    reject
  end

  #
  # Отписывает пользователя от потоков
  #
  def unsubscribed
    Rails.logger.info("UserChannel: User #{current_user&.id || 'Guest'} unsubscribed")
  end
end
