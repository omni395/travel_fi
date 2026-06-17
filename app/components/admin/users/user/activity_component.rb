# frozen_string_literal: true

#
# Admin::Users::User::ActivityComponent - компонент активности пользователя
#
# Отображает активность пользователя из Merit:
# - полученные бейджи
# - начисленные очки
# - действия пользователя
#
# @param user [User] пользователь
#
class Admin::Users::User::ActivityComponent < ApplicationComponent
  def initialize(user:)
    @user = user
    @activities = UserActivityService.new(user: user).call
  end

  private

  attr_reader :user, :activities

  #
  # Проверяет, есть ли активность для отображения
  #
  # @return [Boolean]
  #
  def activities?
    activities.any?
  end

  #
  # Возвращает цвет бейджа в зависимости от типа события
  #
  # @param type [Symbol] тип события (:badge, :score, :action)
  # @return [Symbol] цвет для Ui::BadgeComponent
  #
  def badge_color(type)
    case type
    when :badge then :warning
    when :score then :primary
    when :action then :success
    else :gray
    end
  end

  #
  # Возвращает заголовок события
  #
  # @param event [UserActivityService::ActivityEvent] событие
  # @return [String] переведенный заголовок
  #
  def event_title(event)
    t("admin.users.activity.type_#{event.type}", default: event.title)
  end
end
