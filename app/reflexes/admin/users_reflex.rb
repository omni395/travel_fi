# frozen_string_literal: true

#
# Admin::UsersReflex - обработчик WebSocket событий для управления пользователями
#
# Отвечает за:
# - Обновление данных пользователя
# - Изменение статусов пользователя
# - Управление ролями пользователя
#
class Admin::UsersReflex < ApplicationReflex
  #
  # Обновляет поле пользователя
  # Вызывается при изменении значения поля
  #
  # @param user_id [Integer] ID пользователя
  # @param field [String] название поля
  # @param value [String] новое значение
  #
  def update_field(user_id:, field:, value:)
    user = User.find(user_id)
    authorize_with_pundit!(user, :update?)

    Admin::UserService.update(
      user: user,
      params: { field => value },
      current_user: current_user
    )

    # Model.after_commit вызовет Admin::UserBroadcaster для отправки обновлений
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("User update unauthorized: #{e.message}")
    send_error("You are not authorized to update this user")
  rescue Admin::UserService::UpdateError => e
    Rails.logger.warn("User update failed: #{e.message}")
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("User update error: #{e.class} #{e.message}")
    send_error("An error occurred while updating the user")
  end

  #
  # Изменяет статус пользователя
  # Вызывается при нажатии кнопки изменения статуса
  #
  # @param user_id [Integer] ID пользователя
  # @param status [String] новый статус
  #
  def update_status(user_id:, status:)
    user = User.find(user_id)

    case status
    when 'active'
      authorize_with_pundit!(user, :activate?)
    when 'suspended'
      authorize_with_pundit!(user, :suspend?)
    when 'banned'
      authorize_with_pundit!(user, :ban?)
    when 'pending_verification'
      authorize_with_pundit!(user, :activate?)
    end

    Admin::UserService.change_status(
      user: user,
      status: status,
      current_user: current_user
    )

    # Model.after_commit вызовет Admin::UserBroadcaster для отправки обновлений
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("User status change unauthorized: #{e.message}")
    send_error("You are not authorized to change this user's status")
  rescue Admin::UserService::StatusError => e
    Rails.logger.warn("User status change failed: #{e.message}")
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("User status change error: #{e.class} #{e.message}")
    send_error("An error occurred while changing the user's status")
  end

  #
  # Добавляет роль пользователю
  # Вызывается при выборе роли
  #
  # @param user_id [Integer] ID пользователя
  # @param role_id [Integer] ID роли
  #
  def add_role(user_id:, role_id:)
    user = User.find(user_id)
    authorize_with_pundit!(user, :update_roles?)

    role = Role.find(role_id)
    Admin::UserService.add_role(
      user: user,
      role: role,
      current_user: current_user
    )

    # Model.after_commit вызовет Admin::UserBroadcaster для отправки обновлений
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("User role add unauthorized: #{e.message}")
    send_error("You are not authorized to add roles to this user")
  rescue Admin::UserService::RoleError => e
    Rails.logger.warn("User role add failed: #{e.message}")
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("User role add error: #{e.class} #{e.message}")
    send_error("An error occurred while adding the role")
  end

  #
  # Удаляет роль у пользователя
  # Вызывается при нажатии кнопки удаления роли
  #
  # @param user_id [Integer] ID пользователя
  # @param role_id [Integer] ID роли
  #
  def remove_role(user_id:, role_id:)
    user = User.find(user_id)
    authorize_with_pundit!(user, :update_roles?)

    role = Role.find(role_id)
    Admin::UserService.remove_role(
      user: user,
      role: role,
      current_user: current_user
    )

    # Model.after_commit вызовет Admin::UserBroadcaster для отправки обновлений
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("User role remove unauthorized: #{e.message}")
    send_error("You are not authorized to remove roles from this user")
  rescue Admin::UserService::RoleError => e
    Rails.logger.warn("User role remove failed: #{e.message}")
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("User role remove error: #{e.class} #{e.message}")
    send_error("An error occurred while removing the role")
  end

  #
  # Удаляет пользователя
  # Вызывается при подтверждении удаления
  #
  # @param user_id [Integer] ID пользователя
  #
  def destroy(user_id:)
    user = User.find(user_id)
    authorize_with_pundit!(user, :destroy?)

    Admin::UserService.destroy(
      user: user,
      current_user: current_user
    )

    # Model.after_commit вызовет Admin::UserBroadcaster для отправки обновлений
    send_success("User successfully deleted")
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("User destroy unauthorized: #{e.message}")
    send_error("You are not authorized to delete this user")
  rescue Admin::UserService::DestroyError => e
    Rails.logger.warn("User destroy failed: #{e.message}")
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("User destroy error: #{e.class} #{e.message}")
    send_error("An error occurred while deleting the user")
  end

  #
  # Выбирает пользователя для детального просмотра
  # Вызывается при клике на пользователя в списке
  #
  # @param user_id [Integer] ID пользователя
  #
  def select_user(user_id:)
    user = User.find(user_id)
    authorize_with_pundit!(user, :show?)

    # Этот метод нужен только для авторизации
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("User select unauthorized: #{e.message}")
    send_error("You are not authorized to view this user")
  end

  #
  # Запускает режим редактирования
  # Вызывается при нажатии кнопки редактирования
  #
  # @param user_id [Integer] ID пользователя
  #
  def start_edit(user_id:)
    user = User.find(user_id)
    authorize_with_pundit!(user, :update?)

    # Этот метод нужен только для авторизации
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("User edit unauthorized: #{e.message}")
    send_error("You are not authorized to edit this user")
  end

  #
  # Отменяет режим редактирования
  # Вызывается при нажатии кнопки отмены
  #
  # @param user_id [Integer] ID пользователя
  #
  def cancel_edit(user_id:)
    user = User.find(user_id)
    authorize_with_pundit!(user, :show?)

    # Этот метод нужен только для авторизации
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("User cancel edit unauthorized: #{e.message}")
    send_error("You are not authorized to view this user")
  end

  #
  # Выполняет поиск пользователей
  # Обновляет список пользователей без перезагрузки страницы
  #
  # @param query [String] поисковый запрос
  #
  def search(query:)
    authorize_with_pundit!(User, :index?)

    # Обновляем компонент списка пользователей с фильтрацией
    users = Admin::UserService.search_users(query: query, status: nil)

    # Морфим компонент списка пользователей
    cable_ready.morph(
      selector: "[data-admin-users-list]",
      html: render_users_list(users)
    )

    cable_ready.broadcast
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("Users search unauthorized: #{e.message}")
    send_error("You are not authorized to search users")
  rescue StandardError => e
    Rails.logger.error("Users search error: #{e.class} #{e.message}")
    send_error("An error occurred while searching users")
  end

  #
  # Фильтрует пользователей по статусу
  # Обновляет список пользователей без перезагрузки страницы
  #
  # @param status [String] статус для фильтрации
  #
  def filter_by_status(status:)
    authorize_with_pundit!(User, :index?)

    # Обновляем компонент списка пользователей с фильтрацией
    users = Admin::UserService.search_users(query: nil, status: status)

    # Морфим компонент списка пользователей
    cable_ready.morph(
      selector: "[data-admin-users-list]",
      html: render_users_list(users)
    )

    cable_ready.broadcast
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("Users filter unauthorized: #{e.message}")
    send_error("You are not authorized to filter users")
  rescue StandardError => e
    Rails.logger.error("Users filter error: #{e.class} #{e.message}")
    send_error("An error occurred while filtering users")
  end

  #
  # Сбрасывает фильтры
  # Обновляет список пользователей без перезагрузки страницы
  #
  def reset_filters
    authorize_with_pundit!(User, :index?)

    # Получаем всех пользователей без фильтров
    users = Admin::UserService.search_users(query: nil, status: nil)

    # Морфим компонент списка пользователей
    cable_ready.morph(
      selector: "[data-admin-users-list]",
      html: render_users_list(users)
    )

    cable_ready.broadcast
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("Users reset filters unauthorized: #{e.message}")
    send_error("You are not authorized to reset filters")
  rescue StandardError => e
    Rails.logger.error("Users reset filters error: #{e.class} #{e.message}")
    send_error("An error occurred while resetting filters")
  end

  #
  # Выбирает пользователя для детального просмотра
  # Обновляет детальный вид без перезагрузки страницы
  #
  # @param user_id [Integer] ID пользователя
  #
  def select_user_detail(user_id:)
    user = User.find(user_id)
    authorize_with_pundit!(user, :show?)

    # Морфим компонент детальной информации о пользователе
    cable_ready.morph(
      selector: "[data-admin-user-detail]",
      html: render_user_detail(user)
    )

    cable_ready.broadcast
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("User select detail unauthorized: #{e.message}")
    send_error("You are not authorized to view this user")
  rescue StandardError => e
    Rails.logger.error("User select detail error: #{e.class} #{e.message}")
    send_error("An error occurred while selecting user")
  end

  #
  # Запускает режим редактирования
  # Обновляет форму редактирования без перезагрузки страницы
  #
  # @param user_id [Integer] ID пользователя
  #
  def start_edit_mode(user_id:)
    user = User.find(user_id)
    authorize_with_pundit!(user, :update?)

    # Морфим компонент формы редактирования
    cable_ready.morph(
      selector: "[data-admin-user-detail]",
      html: render_edit_form(user)
    )

    cable_ready.broadcast
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("User start edit mode unauthorized: #{e.message}")
    send_error("You are not authorized to edit this user")
  rescue StandardError => e
    Rails.logger.error("User start edit mode error: #{e.class} #{e.message}")
    send_error("An error occurred while starting edit mode")
  end

  private

  #
  # Рендерит список пользователей
  #
  # @param users [ActiveRecord::Relation] пользователи для рендеринга
  # @return [String] HTML компонента
  #
  def render_users_list(users)
    component = Admin::UsersListComponent.new(
      users: users,
      search_query: nil,
      status_filter: nil,
      selected_user: nil,
      edit_mode: false,
      roles: Role.all
    )

    ApplicationController.helpers.render_component(component)
  end

  #
  # Рендерит детальную информацию о пользователе
  #
  # @param user [User] пользователь для рендеринга
  # @return [String] HTML компонента
  #
  def render_user_detail(user)
    component = Admin::UserDetailComponent.new(
      user: user,
      versions: user.versions.order(created_at: :desc).limit(20)
    )

    ApplicationController.helpers.render_component(component)
  end

  #
  # Рендерит форму редактирования пользователя
  #
  # @param user [User] пользователь для рендеринга
  # @return [String] HTML компонента
  #
  def render_edit_form(user)
    component = Admin::UserEditComponent.new(
      user: user,
      roles: Role.all
    )

    ApplicationController.helpers.render_component(component)
  end

  #
  # Обновляет компонент после изменения пользователя
  # Вызывается после успешного обновления
  #
  def morph_component
    # StimulusReflex автоматически морфит компонент
    # Этот метод можно использовать для дополнительной логики
  end

  private

  #
  # Отправляет ошибку в браузер
  # Dispatch notice или alert через CableReady
  #
  # @param message [String] сообщение об ошибке
  #
  def send_error(message)
    cable_ready[current_user.to_gid_param].dispatch_event(
      name: "adminUsersError",
      detail: { message: message }
    )
    broadcast
  end

  #
  # Отправляет success событие в браузер
  #
  # @param message [String] опциональное сообщение об успехе
  #
  def send_success(message = nil)
    cable_ready[current_user.to_gid_param].dispatch_event(
      name: "adminUsersSuccess",
      detail: { message: message || "Operation successful!" }
    )
    broadcast
  end
end
