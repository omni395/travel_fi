# frozen_string_literal: true

#
# AdminPolicy - политика доступа к админским действиям
#
# Определяет права доступа к админским функциям
# Доступ разрешен только пользователям с ролью admin
#
class AdminPolicy < ApplicationPolicy
  #
  # Может ли пользователь получить доступ к админским функциям?
  # Доступ разрешен: только admin
  #
  # @return [Boolean]
  #
  def access?
    user&.admin?
  end
end
