# frozen_string_literal: true

#
# User Broadcaster - отправляет обновления профиля пользователя через WebSocket
# 
# Вызывается из User.after_commit колбэка после сохранения профиля
# Использует CableReady для морфинга компонента в браузере
#
# Поток: UserService.save! → after_commit → UserBroadcaster.call → CableReady.morph → браузер
#
class UserBroadcaster
  include CableReady::Broadcaster

  #
  # Отправляет обновление профиля пользователя через WebSocket
  #
  # @param user [User] пользователь с обновленными данными
  #
  def self.call(user:)
    new(user: user).broadcast
  end

  attr_reader :user

  def initialize(user:)
    @user = user
  end

  #
  # Выполняет broadcast обновления
  #
  def broadcast
    # Рендерим обновленный компонент
    updated_component_html = render_user_profile_component

    # Отправляем CableReady команды в личный канал пользователя
    cable_ready["user_#{user.id}"].morph(
      selector: "[data-user-profile-id='#{user.id}']",
      html: updated_component_html
    )

    # Dispatch success события для формы
    cable_ready["user_#{user.id}"].dispatch_event(
      name: "usersSuccess",
      detail: { message: "Profile updated successfully!" }
    )

    # Broadcast всех команд в WebSocket канал пользователя
    CableReady::Broadcaster.broadcast_to("user_#{user.id}")

    Rails.logger.info("UserBroadcaster: Sent profile update for user #{user.id}")
  rescue StandardError => e
    Rails.logger.error("UserBroadcaster error: #{e.class} #{e.message}")
  end

  private

  #
  # Рендерит компонент UserProfileComponent для текущего пользователя
  # Возвращает HTML для морфинга
  #
  def render_user_profile_component
    component = UserProfileComponent.new(user: user)
    
    # Используем ApplicationController helpers для рендеринга компонента
    ApplicationController.helpers.render_component(component)
  rescue StandardError => e
    Rails.logger.error("Failed to render UserProfileComponent: #{e.class} #{e.message}")
    ""
  end
end
