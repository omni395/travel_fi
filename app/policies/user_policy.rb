# frozen_string_literal: true

#
# User Policy - определяет правила доступа к профилям пользователей
# Используется Pundit для авторизации в контроллерах и Reflexes
#
# Правила:
# - show?: может видеть профиль - сам пользователь или админ
# - update?: может редактировать профиль - сам пользователь или админ
# - destroy?: может удалить профиль - только админ
#
class UserPolicy < ApplicationPolicy
  #
  # Может ли пользователь просматривать список пользователей?
  # Может просматривать: админ или модератор
  #
  # @return [Boolean]
  #
  def index?
    user.present? && (user.admin? || user.moderator?)
  end

  #
  # Может ли пользователь видеть профиль?
  # Может видеть: свой профиль или админ может видеть любой профиль
  #
  # @return [Boolean]
  #
  def show?
    return false unless user.present?

    user == record || user.admin?
  end

  #
  # Может ли пользователь обновлять профиль?
  # Может обновлять: свой профиль или админ может обновлять любой
  # Используется в UserReflex#update_profile
  #
  # @return [Boolean]
  #
  def update?
    return false unless user.present?

    user == record || user.admin?
  end

  #
  # Может ли пользователь редактировать профиль?
  # Alias для update? (используется в некоторых контекстах)
  #
  # @return [Boolean]
  #
  def edit?
    update?
  end

  #
  # Может ли пользователь удалить профиль?
  # Может удалять: только админ
  #
  # @return [Boolean]
  #
  def destroy?
    return false unless user.present?

    user.admin?
  end

  #
  # Может ли пользователь активировать другого пользователя?
  # Может активировать: только админ
  # Используется при управлении статусами
  #
  # @return [Boolean]
  #
  def activate?
    return false unless user.present?

    user.admin?
  end

  #
  # Может ли пользователь заблокировать другого пользователя?
  # Может блокировать: только админ (кроме себя)
  #
  # @return [Boolean]
  #
  def suspend?
    return false unless user.present?

    user.admin? && user != record
  end

  #
  # Может ли пользователь заморозить профиль?
  # Может замораживать: только админ
  #
  # @return [Boolean]
  #
  def ban?
    return false unless user.present?

    user.admin? && user != record
  end

  #
  # Может ли пользователь изменять роли?
  # Может изменять: только супер-админ
  #
  # @return [Boolean]
  #
  def update_roles?
    return false unless user.present?

    user.admin? && user != record
  end

  #
  # Имеет ли пользователь доступ к админ-панели?
  # Доступна админам и модераторам
  # Используется в NavbarComponent для отображения ссылки на админку
  #
  # @return [Boolean]
  #
  def admin_panel_access?
    return false unless user.present?

    user.admin? || user.moderator?
  end
end
