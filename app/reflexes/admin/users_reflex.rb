# frozen_string_literal: true

#
# Admin::UsersReflex - обработчик WebSocket событий для управления пользователями
#
# Отвечает за:
# - Удаление пользователя
# - Фильтрацию и поиск пользователей
# - Сортировку пользователей
#
class Admin::UsersReflex < ApplicationReflex
  PER_PAGE = 20

  #
  # Обновляет данные пользователя через WebSocket
  # Вызывается из формы редактирования (EditComponent)
  #
  # @param params [Hash] параметры { name:, email:, status:, role_id: }
  #
  def update(params = {})
    morph :nothing

    user = User.friendly.find(params[:id] || element.dataset.id)
    authorize_with_pundit!(user, :update?)

    Admin::UserService.update(
      user: user,
      params: params,
      current_user: current_user
    )

    # После успешного обновления морфим профиль
    component = Admin::Users::User::ShowComponent.new(user: user)
    html = ApplicationController.render(component, layout: false)
    morph "#user-profile", html

    send_success(I18n.t("admin.users.update_success"))
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("User update unauthorized: #{e.message}")
    send_error(I18n.t("reflexes.admin.users.update_unauthorized"))
  rescue Admin::UserService::UpdateError => e
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("User update error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.users.update_error"))
  end

  #
  # Удаляет пользователя
  # Вызывается при подтверждении удаления
  #
  # @param params [Hash] параметры { user_id: Integer }
  #
  def destroy(params)
    morph :nothing

    user_id = params[:user_id]
    user = User.friendly.find(user_id)
    authorize_with_pundit!(user, :destroy?)

    Admin::UserService.destroy(
      user: user,
      current_user: current_user
    )

    # После удаления редиректим на список пользователей
    cable_ready.redirect_to(url: admin_users_path)
    cable_ready.broadcast
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("User destroy unauthorized: #{e.message}")
    send_error(I18n.t("reflexes.admin.users.destroy_unauthorized"))
  rescue Admin::UserService::DestroyError => e
    Rails.logger.warn("User destroy failed: #{e.message}")
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("User destroy error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.users.destroy_error"))
  end

  #
  # Фильтрует пользователей по запросу и/или статусу (AND)
  # Обновляет список пользователей без перезагрузки страницы
  #
  # @param params [Hash] параметры { query: String, status: String, page: Integer }
  #
  def filter(params = {})
    query = params[:query]
    status = params[:status]
    page = (params[:page] || 1).to_i
    sort_column = params[:sort_column] || session[:admin_users_sort_column]
    sort_direction = params[:sort_direction] || session[:admin_users_sort_direction]
    authorize_with_pundit!(User, :index?)

    # Сохраняем сортировку в сессии
    session[:admin_users_sort_column] = sort_column
    session[:admin_users_sort_direction] = sort_direction

    # Пагинируем отфильтрованных пользователей
    users = Admin::UserService.search_users(query: query, status: status, sort_column: sort_column, sort_direction: sort_direction)
    @pagy, users = pagy(users, limit: PER_PAGE, page: page)

    # Морфим компонент таблицы пользователей через Selector Morph
    morph "[data-admin-users-list]", render_users_table(users, @pagy)
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("Users filter unauthorized: #{e.message}")
    send_error(I18n.t("reflexes.admin.users.filter_unauthorized"))
  rescue StandardError => e
    Rails.logger.error("Users filter error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.users.filter_error"))
  end

  #
  # Сортирует пользователей по указанной колонке
  # Переключает направление сортировки при повторном клике
  #
  # @param params [Hash] параметры { column: String, query: String, status: String }
  #
  def sort(params = {})
    morph :nothing

    column = params[:column]
    query = params[:query]
    status = params[:status]
    authorize_with_pundit!(User, :index?)

    # Переключаем направление сортировки
    current_column = session[:admin_users_sort_column]
    current_direction = session[:admin_users_sort_direction]

    if current_column == column
      # Переключаем направление
      new_direction = current_direction == 'asc' ? 'desc' : 'asc'
    else
      # Новая колонка — начинаем с asc
      new_direction = 'asc'
    end

    session[:admin_users_sort_column] = column
    session[:admin_users_sort_direction] = new_direction

    # Пагинируем отсортированных пользователей
    users = Admin::UserService.search_users(query: query, status: status, sort_column: column, sort_direction: new_direction)
    @pagy, users = pagy(users, limit: PER_PAGE, page: 1)

    # Морфим компонент таблицы пользователей через Selector Morph
    morph "[data-admin-users-list]", render_users_table(users, @pagy)
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("Users sort unauthorized: #{e.message}")
    send_error(I18n.t("reflexes.admin.users.filter_unauthorized"))
  rescue StandardError => e
    Rails.logger.error("Users sort error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.users.filter_error"))
  end

  #
  # Сбрасывает фильтры
  # Обновляет список пользователей без перезагрузки страницы
  #
  def reset_filters
    morph :nothing

    authorize_with_pundit!(User, :index?)

    # Сбрасываем сортировку в сессии
    session.delete(:admin_users_sort_column)
    session.delete(:admin_users_sort_direction)

    # Получаем всех пользователей без фильтров (первая страница)
    users = Admin::UserService.search_users(query: nil, status: nil)
    @pagy, users = pagy(users, limit: PER_PAGE, page: 1)

    # Морфим компонент таблицы пользователей через Selector Morph
    morph "[data-admin-users-list]", render_users_table(users, @pagy)
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("Users reset filters unauthorized: #{e.message}")
    send_error(I18n.t("reflexes.admin.users.reset_filters_unauthorized"))
  rescue StandardError => e
    Rails.logger.error("Users reset filters error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.users.reset_filters_error"))
  end

  private

  #
  # Рендерит таблицу пользователей (для morph)
  #
  # @param users [ActiveRecord::Relation] пользователи для рендеринга
  # @param pagy [Pagy, nil] объект пагинации
  # @return [String] HTML компонента таблицы
  #
  def render_users_table(users, pagy = nil)
    component = Admin::Users::TableComponent.new(users: users, pagy: pagy)

    ApplicationController.render(component, layout: false)
  end

  #
  # Отправляет ошибку в браузер
  # Dispatch notice или alert через CableReady
  #
  # @param message [String] сообщение об ошибке
  #
  def send_error(message)
    return unless current_user

    cable_ready[current_user.to_gid_param].dispatch_event(
      name: "adminUsersError",
      detail: { message: message }
    )
    cable_ready.broadcast
  end

  #
  # Отправляет success событие в браузер
  #
  # @param message [String] опциональное сообщение об успехе
  #
  def send_success(message = nil)
    return unless current_user

    cable_ready[current_user.to_gid_param].dispatch_event(
      name: "adminUsersSuccess",
      detail: { message: message || I18n.t("reflexes.admin.users.operation_success") }
    )
    cable_ready.broadcast
  end
end
