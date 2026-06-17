# frozen_string_literal: true

#
# Admin::UserBroadcaster - бродкастер для отправки обновлений пользователей
#
# Ответственность:
# 1. Отправляет обновление профиля пользователя через WebSocket
# 2. Отправляет уведомления о действиях с пользователями
# 3. Использует CableReady для морфинга компонентов
#
# Использование:
#   Admin::UserBroadcaster.broadcast_user_update(user)
#   Admin::UserBroadcaster.broadcast_user_destroy(user)
#
class Admin::UserBroadcaster
  include CableReady::Broadcaster
  #
  # Отправляет обновление профиля пользователя
  # Вызывается после успешного обновления пользователя
  #
  # @param user [User] обновленный пользователь
  #
  def self.broadcast_user_update(user)
    new(user).send_user_update(user)
  end

  #
  # Отправляет уведомление о создании нового пользователя
  # Препендикс строку нового пользователя в таблицу админки
  #
  # @param user [User] созданный пользователь
  #
  def self.broadcast_user_created(user)
    new(user).send_user_created(user)
  end

  #
  # Отправляет уведомление об удалении пользователя
  # Вызывается после успешного удаления пользователя
  #
  # @param user [User] удаленный пользователь
  #
  def self.broadcast_user_destroy(user)
    new(user).send_user_destroy(user)
  end

  #
  # Отправляет уведомление об изменении статуса пользователя
  # Вызывается после успешного изменения статуса
  #
  # @param user [User] пользователь с измененным статусом
  # @param old_status [String] старый статус
  # @param new_status [String] новый статус
  #
  def self.broadcast_status_change(user, old_status, new_status)
    new(user).send_status_change(user, old_status, new_status)
  end

  #
  # Отправляет уведомление об изменении ролей пользователя
  # Вызывается после успешного изменения ролей
  #
  # @param user [User] пользователь с измененными ролями
  # @param role_name [String] название роли
  # @param action [Symbol] действие (:add или :remove)
  #
  def self.broadcast_role_change(user, role_name, action)
    new(user).send_role_change(user, role_name, action)
  end

  attr_reader :user

  def initialize(user)
    @user = user
  end

  #
  # Отправляет обновление профиля пользователя
  # Морфит строку пользователя в таблице
  #
  def send_user_update(user)
    # Морфим строку пользователя в таблице
    cable_ready["AdminChannel"].morph(
      selector: "[data-admin-user-id='#{user.id}']",
      html: render_user_row_component(user)
    )

    # Отправляем уведомление об успехе
    cable_ready["AdminChannel"].dispatch_event(
      name: "adminUserUpdateSuccess",
      detail: {
        user_id: user.id,
        message: I18n.t('admin.users.update_success')
      }
    )

    cable_ready["AdminChannel"].broadcast
  end

  #
  # Отправляет уведомление об удалении пользователя
  # Удаляет строку пользователя из списка
  #
  def send_user_destroy(user)
    # Удаляем строку пользователя из списка
    cable_ready["AdminChannel"].remove(
      selector: "[data-admin-user-id='#{user.id}']"
    )

    # Отправляем уведомление об успехе
    cable_ready["AdminChannel"].dispatch_event(
      name: "adminUserDestroySuccess",
      detail: {
        user_id: user.id,
        message: I18n.t('admin.users.destroy_success')
      }
    )

    cable_ready["AdminChannel"].broadcast
  end

  #
  # Отправляет уведомление об изменении статуса пользователя
  # Обновляет бейдж статуса в компонентах
  #
  def send_status_change(user, old_status, new_status)
    # Обновляем бейдж статуса в детальной информации
    cable_ready["AdminChannel"].morph(
      selector: "[data-admin-user-status='#{user.id}']",
      html: render_status_badge(user)
    )

    # Отправляем уведомление об успехе
    status_message = I18n.t("admin.users.#{new_status}_success")
    cable_ready["AdminChannel"].dispatch_event(
      name: "adminUserStatusChangeSuccess",
      detail: {
        user_id: user.id,
        old_status: old_status,
        new_status: new_status,
        message: status_message
      }
    )

    cable_ready["AdminChannel"].broadcast
  end

  #
  # Отправляет уведомление об изменении ролей пользователя
  # Обновляет список ролей в компонентах
  #
  def send_role_change(user, role_name, action)
    # Обновляем список ролей в детальной информации
    cable_ready["AdminChannel"].morph(
      selector: "[data-admin-user-roles='#{user.id}']",
      html: render_user_roles(user)
    )

    # Отправляем уведомление об успехе
    role_message = action == :add ? 
      I18n.t('admin.users.role_added') : 
      I18n.t('admin.users.role_removed')

    cable_ready["AdminChannel"].dispatch_event(
      name: "adminUserRoleChangeSuccess",
      detail: {
        user_id: user.id,
        role_name: role_name,
        action: action,
        message: role_message
      }
    )

    cable_ready["AdminChannel"].broadcast
  end

  private

  #
  # Отправляет уведомление о создании нового пользователя
  # Препендикс строку нового пользователя в начало таблицы админки
  #
  def send_user_created(user)
    # Препендикс строку нового пользователя в таблицу
    cable_ready["AdminChannel"].prepend(
      selector: "[data-admin-users-list] tbody",
      html: render_user_row_component(user)
    )

    # Отправляем уведомление об успехе
    cable_ready["AdminChannel"].dispatch_event(
      name: "adminUserCreatedSuccess",
      detail: {
        user_id: user.id,
        message: I18n.t('admin.users.create_success')
      }
    )

    cable_ready["AdminChannel"].broadcast
  end

  #
  # Рендерит строку пользователя для списка
  #
  # @param user [User] пользователь для рендеринга
  # @return [String] HTML компонента
  #
  def render_user_row_component(user)
    component = Admin::Users::RowComponent.new(user: user)
    ApplicationController.render(component, layout: false)
  end

  #
  # Рендерит бейдж статуса пользователя
  #
  # @param user [User] пользователь для рендеринга
  # @return [String] HTML бейджа
  #
  def render_status_badge(user)
    status_class = case user.status
    when 'active'
      'bg-green-100 text-green-800'
    when 'pending_verification'
      'bg-yellow-100 text-yellow-800'
    when 'suspended'
      'bg-orange-100 text-orange-800'
    when 'banned'
      'bg-red-100 text-red-800'
    when 'deleted'
      'bg-gray-100 text-gray-800'
    else
      'bg-gray-100 text-gray-800'
    end

    ApplicationController.helpers.tag.span(
      I18n.t("activerecord.attributes.user.statuses.#{user.status}"),
      class: "px-2 inline-flex text-xs leading-5 font-semibold rounded-full #{status_class}"
    )
  end

  #
  # Рендерит список ролей пользователя
  #
  # @param user [User] пользователь для рендеринга
  # @return [String] HTML списка ролей
  #
  def render_user_roles(user)
    roles_html = user.roles.map do |role|
      ApplicationController.helpers.tag.span(
        role.name,
        class: 'px-2 py-1 text-xs font-medium rounded bg-teal-100 text-teal-800 mr-1'
      )
    end.join

    ApplicationController.helpers.tag.div(
      roles_html,
      class: 'flex flex-wrap gap-1'
    )
  end
end
