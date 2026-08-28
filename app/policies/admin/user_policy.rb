# frozen_string_literal: true

#
# Admin::UserPolicy - политика для управления пользователями
#
# Определяет права доступа к управлению пользователями
#
class Admin::UserPolicy < ApplicationPolicy
  #
  # Проверяет доступ к списку пользователей
  # Доступен только администраторам и модераторам
  #
  # @return [Boolean] true если пользователь имеет доступ
  #
  def index?
    user.admin? || user.moderator?
  end

  #
  # Проверяет доступ к детальной информации пользователя
  # Доступен администраторам и модераторам
  #
  # @return [Boolean] true если пользователь имеет доступ
  #
  def show?
    user.admin? || user.moderator?
  end

  #
  # Проверяет право на редактирование пользователя
  # Доступно только администраторам
  #
  # @return [Boolean] true если пользователь имеет право
  #
  def update?
    user.admin?
  end

  #
  # Проверяет право на удаление пользователя
  # Доступно только администраторам
  # Нельзя удалять самого себя
  #
  # @return [Boolean] true если пользователь имеет право
  #
  def destroy?
    user.admin? && user != record
  end

  #
  # Проверяет право на активацию пользователя
  # Доступно только администраторам
  #
  # @return [Boolean] true если пользователь имеет право
  #
  def activate?
    user.admin?
  end

  #
  # Проверяет право на приостановку пользователя
  # Доступно только администраторам
  # Нельзя приостанавливать самого себя
  #
  # @return [Boolean] true если пользователь имеет право
  #
  def suspend?
    user.admin? && user != record
  end

  #
  # Проверяет право на бан пользователя
  # Доступно только администраторам
  # Нельзя банить самого себя
  #
  # @return [Boolean] true если пользователь имеет право
  #
  def ban?
    user.admin? && user != record
  end

  #
  # Проверяет право на восстановление пользователя
  # Доступно только администраторам
  #
  # @return [Boolean] true если пользователь имеет право
  #
  def restore?
    user.admin?
  end

  #
  # Проверяет право на управление ролями пользователя
  # Доступно только администраторам
  # Нельзя менять роли самому себе
  #
  # @return [Boolean] true если пользователь имеет право
  #
  def update_roles?
    user.admin? && user != record
  end

  #
  # Scope для ограничения списка пользователей
  # Модераторы видят только активных пользователей
  # Администраторы видят всех пользователей
  #
  # @return [ActiveRecord::Relation] scope для запросов
  #
  class Scope < Scope
    def resolve
      if user.admin?
        scope.all
      elsif user.moderator?
        # Модераторы видят только активных пользователей
        scope.where(status: "active")
      else
        scope.none
      end
    end
  end
end
