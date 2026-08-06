# frozen_string_literal: true

#
# Admin::DashboardReflex - обработчик WebSocket событий для админ-дашборда
#
# Отвечает за:
# - Обновление статистики в реальном времени
# - Обновление списка последних пользователей
# - Обновление списка последних активностей
#
class Admin::DashboardReflex < ApplicationReflex
  #
  # Обновляет весь дашборд
  # Вызывается при нажатии кнопки обновления
  #
  def refresh
    morph :nothing

    # Проверяем авторизацию через Pundit
    authorize :admin_dashboard, :access?

    # Получаем обновленную статистику
    @stats = Admin::DashboardService.stats
    @recent_users = User.order(created_at: :desc).limit(10)
    @recent_activities = PaperTrail::Version.order(created_at: :desc).limit(20)

    # Отправляем обновление через CableReady
    morph_dashboard
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("Dashboard refresh unauthorized: #{e.message}")
    morph :nothing
  end

  #
  # Обновляет статистику дашборда
  # Вызывается автоматически при изменении данных
  #
  def refresh_stats
    morph :nothing

    # Проверяем авторизацию через Pundit
    authorize :admin_dashboard, :access?

    # Получаем обновленную статистику
    @stats = Admin::DashboardService.stats
    @recent_users = User.order(created_at: :desc).limit(10)
    @recent_activities = PaperTrail::Version.order(created_at: :desc).limit(20)

    # Отправляем обновление через CableReady
    morph_dashboard
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("Dashboard refresh unauthorized: #{e.message}")
    morph :nothing
  end

  private

  #
  # Морфинг дашборда через CableReady
  # Обновляет только изменившиеся элементы
  #
  def morph_dashboard
    cable_ready["user_#{current_user.id}"].morph(
      selector: "[data-admin--dashboard]",
      html: render_dashboard_component
    ).broadcast
  end

  #
  # Рендерит компонент дашборда
  # Возвращает HTML для морфинга
  #
  # @return [String] HTML компонента
  #
  def render_dashboard_component
    component = Admin::DashboardComponent.new(
      stats: @stats,
      recent_users: @recent_users,
      recent_activities: @recent_activities
    )

    ApplicationController.render(component, layout: false)
  end
end
