# frozen_string_literal: true

#
# User Profile Component - отображает профиль пользователя
# Показывает аватар, имя, email, статус, репутацию, points, badges, роли
# Используется на страницах профилей и в админ-панели
#
# @param user [User] пользователь для отображения
#
class UserProfileComponent < ApplicationComponent
  def initialize(user:)
    @user = user
  end

  #
  # Возвращает CSS классы для бейджа статуса в зависимости от статуса
  #
  def status_badge_class
    case @user.status
    when "active"
      "badge badge-success"
    when "pending_verification"
      "badge badge-warning"
    when "suspended"
      "badge badge-error"
    when "banned"
      "badge badge-error"
    when "deleted"
      "badge badge-neutral"
    else # registered
      "badge badge-info"
    end
  end

  #
  # Возвращает список ролей пользователя через запятую
  #
  def user_roles
    @user.roles.pluck(:name).join(", ") || "—"
  end

  #
  # Возвращает список бейджей через запятую
  #
  def user_badges
    (@user.badges || []).join(", ") || "—"
  end

  #
  # Проверяет может ли текущий пользователь редактировать профиль
  #
  def can_edit_profile?
    user_signed_in? && (current_user == @user || current_user.admin?)
  end

  #
  # Возвращает инициал имени для avatar fallback
  #
  def name_initial
    @user.name.first.upcase
  end
end
