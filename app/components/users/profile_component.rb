# frozen_string_literal: true

#
# Users::ProfileComponent - отображает профиль пользователя
#
# Показывает аватар, имя, email, статус, репутацию, points, badges, роли
# Используется на страницах профилей и в админ-панели
#
# @param user [User] пользователь для отображения
#
class Users::ProfileComponent < ApplicationComponent
  def initialize(user:)
    @user = user
  end

  private

  attr_reader :user

  #
  # Возвращает цвет для Ui::BadgeComponent в зависимости от статуса
  #
  # @return [Symbol] цвет (:success, :warning, :error, :gray, :primary)
  #
  def status_color
    case user.status
    when "active" then :success
    when "pending_verification" then :warning
    when "suspended" then :error
    when "banned" then :error
    when "deleted" then :gray
    else :primary
    end
  end

  #
  # Проверяет может ли текущий пользователь редактировать профиль
  #
  def can_edit_profile?
    helpers.user_signed_in? && (helpers.current_user == user || helpers.policy(user).edit?)
  end
end
