# frozen_string_literal: true

#
# SettingPolicy - политика доступа к настройкам пользователя
#
# Пользователь может управлять только своими настройками
#
class SettingPolicy < ApplicationPolicy
  #
  # Может ли пользователь просматривать страницу настроек?
  # Только владелец настроек
  #
  def show?
    user.present? && record.user == user
  end

  #
  # Может ли пользователь обновлять настройки?
  # Только владелец настроек
  #
  def update?
    user.present? && record.user == user
  end
end
