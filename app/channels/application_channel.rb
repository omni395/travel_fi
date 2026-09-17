# frozen_string_literal: true

#
# ApplicationChannel - канал для подписки всех пользователей на обновления
#
# Этот канал используется для отправки обновлений в реальном времени
# всем пользователям приложения
#
# Подписка:
#   - Все аутентифицированные пользователи могут подписаться
#   - Подписка происходит автоматически при загрузке приложения
#
module ApplicationCable
  class ApplicationChannel < Channel
    #
    # Подписывает пользователя на канал
    # Проверяет аутентификацию перед подпиской
    #
    def subscribed
      # ЛОГИРУЕМ ВСЕ ПОПЫТКИ подписки
      puts "[CHANNEL] ApplicationChannel.subscribed() called at #{Time.current}"
      Rails.logger.warn("[CHANNEL] ApplicationChannel.subscribed() called - current_user: #{current_user&.id}")
      
      # Проверяем, аутентифицирован ли пользователь
      if !current_user
        puts "[CHANNEL] REJECTED: current_user is nil"
        Rails.logger.warn("[CHANNEL] ApplicationChannel: Subscription rejected - current_user is nil")
        return reject
      end

      puts "[CHANNEL] ACCEPTING: subscribing user #{current_user.id}"
      Rails.logger.info("[CHANNEL] ApplicationChannel: User #{current_user.id} subscribing to application_channel")
      stream_from "application_channel"

      puts "[CHANNEL] SUCCESS: User #{current_user.id} subscribed"
      Rails.logger.info("[CHANNEL] ApplicationChannel: User #{current_user.id} subscribed to application_channel")
    rescue StandardError => e
      puts "[CHANNEL] ERROR: #{e.class} #{e.message}"
      Rails.logger.error("[CHANNEL] ApplicationChannel subscription error: #{e.class} #{e.message}")
      reject
    end

    #
    # Отписывает пользователя от канала
    #
    def unsubscribed
      Rails.logger.info("ApplicationChannel: User #{current_user.id} unsubscribed from application_channel")
    end
  end
end
