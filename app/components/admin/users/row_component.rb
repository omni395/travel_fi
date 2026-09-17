# frozen_string_literal: true

#
# Admin::Users::RowComponent - строка таблицы пользователей
#
# Отображает одну строку в таблице списка пользователей
# Используется для CableReady морфинга отдельных строк
#
# @param user [User] пользователь для отображения
#
class Admin::Users::RowComponent < ApplicationComponent
  def initialize(user:)
    @user = user
  end

  private

  attr_reader :user

  #
  # Возвращает CSS класс для статуса пользователя
  #
  # @param status [String] статус пользователя
  # @return [String] CSS класс
  #
  def status_badge_class(status)
    case status.to_s
    when 'active'
      'badge-success'
    when 'pending_verification'
      'badge-warning'
    when 'suspended'
      'badge-warning'
    when 'banned'
      'badge-error'
    when 'deleted'
      'badge-neutral'
    else
      'badge-neutral'
    end
  end
end
