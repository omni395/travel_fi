# frozen_string_literal: true

#
# Admin::SettingPolicy - политика доступа к настройкам админа
#
# Доступ к настройкам имеют только admin и moderator
#
class Admin::SettingPolicy < ApplicationPolicy
  #
  # Разрешает просмотр настроек админа
  #
  # @return [Boolean] true если пользователь admin или moderator
  #
  def show?
    user.admin? || user.moderator?
  end
end
