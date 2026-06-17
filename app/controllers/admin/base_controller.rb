 # frozen_string_literal: true

#
# Admin::BaseController - базовый контроллер для админ-панели
#
# Обеспечивает:
# - Авторизацию администраторов и модераторов
# - Защиту от CSRF атак
# - Общую логику для всех админских контроллеров
#
class Admin::BaseController < ApplicationController
  layout 'admin'
  # Отключаем CSRF защиту для API запросов
  protect_from_forgery with: :exception, unless: -> { request.format.json? }

  # Проверяем авторизацию для всех действий
  before_action :authenticate_user!
  before_action :require_admin_or_moderator!

  # Используем Pundit для авторизации
  include Pundit::Authorization

  # Обработка ошибок авторизации
  rescue_from Pundit::NotAuthorizedError, with: :user_not_authorized

  private

  #
  # Проверяет, что пользователь имеет роль администратора или модератора
  # Перенаправляет на главную страницу если нет доступа
  #
  def require_admin_or_moderator!
    return if current_user && policy(current_user).admin_panel_access?

    redirect_to root_path, alert: I18n.t('admin.access_denied')
  end

  #
  # Обработка ошибки авторизации
  # Перенаправляет на предыдущую страницу с сообщением об ошибке
  #
  # @param exception [Pundit::NotAuthorizedError] исключение авторизации
  #
  def user_not_authorized(exception)
    policy_name = exception.policy.class.to_s.underscore

    message = t("#{policy_name}.#{exception.query}", scope: "pundit", default: :default)
    redirect_to(request.referrer || root_path, alert: message)
  end
end
