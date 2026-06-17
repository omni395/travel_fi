# frozen_string_literal: true

#
# Admin::Users::User::ShowComponent - компонент просмотра профиля пользователя
#
# Отображает:
# - Аватар, имя, email, статус
# - Даты регистрации и обновления
# - Роли пользователя (бейджи)
#
# @param user [User] пользователь для отображения
#
class Admin::Users::User::ShowComponent < ApplicationComponent
  def initialize(user:)
    @user = user
  end

  private

  attr_reader :user

  #
  # Возвращает CSS класс для бейджа статуса
  #
  # @return [String] CSS класс
  #
  def status_badge_class
    case user.status
    when 'active' then 'bg-green-100 text-green-800'
    when 'pending_verification' then 'bg-yellow-100 text-yellow-800'
    when 'suspended' then 'bg-orange-100 text-orange-800'
    when 'banned' then 'bg-red-100 text-red-800'
    when 'deleted' then 'bg-gray-100 text-gray-800'
    else 'bg-gray-100 text-gray-800'
    end
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

  #
  # Возвращает текст статуса
  #
  # @return [String] текст статуса
  #
  def status_text
    t("activerecord.attributes.user.statuses.#{user.status}")
  end
end
