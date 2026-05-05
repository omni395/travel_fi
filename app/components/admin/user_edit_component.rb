# frozen_string_literal: true

#
# Admin::UserEditComponent - компонент формы редактирования пользователя
#
# Отображает:
# - Форму редактирования пользователя
# - Управление ролями пользователя
#
# @param user [User] пользователь для редактирования
# @param roles [Array<Role>] список доступных ролей
#
class Admin::UserEditComponent < ApplicationComponent
  def initialize(user:, roles:)
    @user = user
    @roles = roles
  end

  private

  attr_reader :user, :roles

  #
  # Возвращает CSS класс для статуса пользователя
  #
  # @return [String] CSS класс
  #
  def status_badge_class
    case user.status
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
  end

  #
  # Проверяет, имеет ли пользователь роль
  #
  # @param role [Role] роль для проверки
  # @return [Boolean] true если у пользователя есть роль
  #
  def user_has_role?(role)
    user.has_role?(role.name)
  end
end
