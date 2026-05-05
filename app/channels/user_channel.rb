# frozen_string_literal: true

#
# UserChannel - личный канал для каждого пользователя
#
# Каждый пользователь подписан на свой личный канал, который используется для:
# - Отправки обновлений профиля
# - Отправки уведомлений
# - Отправки обновлений связанных с пользователем данными
#
# Подписка:
#   - Пользователь подписывается на канал со своим ID
#   - Канал имеет формат: "user_#{user_id}"
#
class UserChannel < ActionCable::Channel::Base
  include CableReady::Broadcaster
    #
    # Подписывает пользователя на его личный канал
    # Проверяет аутентификацию перед подпиской
    #
    def subscribed
      # Проверяем, аутентифицирован ли пользователь
      return reject unless current_user

      # Подписываем на личный канал пользователя
      stream_from "user_#{current_user.id}"

      Rails.logger.info("UserChannel: User #{current_user.id} subscribed to user_#{current_user.id}")
    rescue StandardError => e
      Rails.logger.error("UserChannel subscription error: #{e.class} #{e.message}")
      reject
    end

    #
    # Отписывает пользователя от канала
    #
    def unsubscribed
      Rails.logger.info("UserChannel: User #{current_user.id} unsubscribed from user_#{current_user.id}")
    end
end
