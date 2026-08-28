# frozen_string_literal: true

#
# Admin::DashboardPolicy - политика для доступа к админ-дашборду
#
# Определяет права доступа к дашборду и его функциям
#
class Admin::DashboardPolicy < ApplicationPolicy
  #
  # Проверяет доступ к дашборду
  # Доступен только администраторам и модераторам
  #
  # @return [Boolean] true если пользователь имеет доступ
  #
  def access?
    user.admin? || user.moderator?
  end

  #
  # Проверяет право на обновление статистики
  # Доступно только администраторам
  #
  # @return [Boolean] true если пользователь имеет право
  #
  def refresh?
    user.admin?
  end

  #
  # Проверяет право на просмотр статистики
  # Доступно администраторам и модераторам
  #
  # @return [Boolean] true если пользователь имеет право
  #
  def show?
    access?
  end

  #
  # Проверяет право на просмотр списка последних пользователей
  # Доступно администраторам и модераторам
  #
  # @return [Boolean] true если пользователь имеет право
  #
  def show_recent_users?
    access?
  end

  #
  # Проверяет право на просмотр списка последних активностей
  # Доступно только администраторам
  #
  # @return [Boolean] true если пользователь имеет право
  #
  def show_recent_activities?
    user.admin?
  end

  #
  # Scope для ограничения данных в дашборде
  # Модераторы видят ограниченный набор данных
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
