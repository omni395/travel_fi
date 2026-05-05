# frozen_string_literal: true

#
# AdminStatsService - сервис для получения статистики админки
#
# Собирает и возвращает статистику по пользователям и активности
#
class AdminStatsService
  #
  # Основной входной метод для получения статистики
  #
  # @return [Hash] хэш со статистикой
  #
  def self.call
    new.execute
  end

  #
  # Выполняет сбор статистики
  #
  # @return [Hash] хэш со статистикой
  #
  def execute
    {
      total_users: User.count,
      active_users: User.active.count,
      suspended_users: User.suspended.count + User.banned.count,
      new_users_today: User.where('created_at >= ?', Date.today.beginning_of_day).count
    }
  end
end
