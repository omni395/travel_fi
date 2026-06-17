# frozen_string_literal: true

#
# Admin::Users::User::EditComponent - компонент формы редактирования пользователя
#
# Отображает:
# - Форму редактирования с полями: name, email, status (DropdownComponent), role (DropdownComponent)
# - Аватар с возможностью загрузки
# - Информационные строки (registered, updated, last_sign_in)
#
# @param user [User] пользователь для редактирования
# @param roles [Array<Role>] список доступных ролей
#
class Admin::Users::User::EditComponent < ApplicationComponent
  def initialize(user:, roles:)
    @user = user
    @roles = roles
  end

  private

  attr_reader :user, :roles

  #
  # Возвращает текст статуса
  #
  # @return [String] текст статуса
  #
  def status_text
    t("activerecord.attributes.user.statuses.#{user.status}")
  end

  #
  # Возвращает опции для выпадающего списка статуса
  #
  # @return [Array<Array<String, String>>] массив [label, value]
  #
  def status_options
    User.statuses.keys.map do |s|
      [t("activerecord.attributes.user.statuses.#{s}"), s]
    end
  end

  #
  # Возвращает опции для выпадающего списка ролей
  #
  # @return [Array<Array<String, String>>] массив [label, value]
  #
  def role_options
    roles.map do |r|
      [t("admin.roles.#{r.name}", default: r.name), r.id]
    end
  end

  #
  # Возвращает ID текущей роли пользователя или ID роли "user" по умолчанию
  #
  # @return [Integer] ID роли
  #
  def current_role_id
    user.roles.first&.id || default_role_id
  end

  #
  # Возвращает название текущей роли пользователя
  #
  # @return [String] название роли
  #
  def current_role_name
    role_name = user.roles.first&.name || 'user'
    t("admin.roles.#{role_name}", default: 'User')
  end

  #
  # Возвращает ID роли "user" по умолчанию
  #
  # @return [Integer] ID роли
  #
  def default_role_id
    Role.find_by(name: 'user')&.id
  end

  #
  # Форматирует дату
  #
  # @param date [DateTime, nil] дата
  # @return [String] отформатированная дата
  #
  def format_date(date)
    return t('admin.users.never') unless date.present?

    l(date, format: :long)
  end
end
