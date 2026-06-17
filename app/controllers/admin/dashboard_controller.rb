# frozen_string_literal: true

#
# Admin::DashboardController - контроллер админ-панели
#
# Отвечает за отображение главной страницы админки со статистикой
# Доступ только для пользователей с ролями admin или moderator
#
class Admin::DashboardController < Admin::BaseController
  #
  # Отображает главную страницу админки со статистикой
  # Показывает: количество пользователей, активных сессий, последние действия
  #
  def index
    authorize :admin_dashboard, :access?

    @stats = UserService.stats
    @recent_users = User.order(created_at: :desc).limit(10)
    @recent_activities = PaperTrail::Version.order(created_at: :desc).limit(20)
  end
end
