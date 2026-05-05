# frozen_string_literal: true

#
# Admin::UserDetailComponent - компонент детальной информации о пользователе
#
# Отображает:
# - Детальную информацию о пользователе
# - Историю изменений (версии)
#
# @param user [User] пользователь для отображения
# @param versions [Array<PaperTrail::Version>] история изменений
#
class Admin::UserDetailComponent < ApplicationComponent
  def initialize(user:, versions:)
    @user = user
    @versions = versions
  end

  private

  attr_reader :user, :versions

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
  # Форматирует дату
  #
  # @param date [DateTime] дата для форматирования
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
