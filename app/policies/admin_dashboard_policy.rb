# frozen_string_literal: true

#
# AdminDashboardPolicy - политика доступа к админ-панели
#
# Определяет права доступа к админ-панели
# Доступ разрешен только пользователям с ролями admin или moderator
#
class AdminDashboardPolicy < ApplicationPolicy
  #
  # Может ли пользователь получить доступ к админ-панели?
  # Доступ разрешен: admin или moderator
  #
  # @return [Boolean]
  #
  def access?
    user&.admin? || user&.moderator?
  end
end
