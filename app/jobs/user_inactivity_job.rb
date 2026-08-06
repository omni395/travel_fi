# frozen_string_literal: true

#
# UserInactivityJob — периодическая проверка неактивных пользователей.
#
# Переводит active-пользователей без активности за 6+ месяцев в статус inactive
# (жизненный цикл юзера, см. ROADMAP 4.1). Логика — в UserService
# (UserService.mark_inactive_old_users), здесь только запуск.
#
# Расписание: config/recurring.yml (SolidQueue Recurring).
#
class UserInactivityJob < ApplicationJob
  queue_as :default

  #
  # Запускает проверку неактивности
  #
  def perform
    marked = UserService.mark_inactive_old_users
    Rails.logger.info("UserInactivityJob: #{marked} users marked inactive")
  end
end
