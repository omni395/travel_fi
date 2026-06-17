# frozen_string_literal: true

#
# SettingBroadcaster - отправляет обновления настроек пользователя через WebSocket
#
# Ответственность:
# 1. Получает обновленный объект Setting
# 2. Формирует CableReady команды для обновления UI
# 3. Отправляет команды в канал конкретного пользователя
#
class SettingBroadcaster
  include CableReady::Broadcaster

  #
  # Отправляет обновление настроек через WebSocket
  #
  # @param setting [Setting] обновленные настройки
  #
  def self.call(setting:)
    new(setting: setting).broadcast
  end

  attr_reader :setting

  def initialize(setting:)
    @setting = setting
  end

  #
  # Выполняет broadcast обновления
  #
  def broadcast
    user = setting.user
    return unless user

    channel = "user_#{user.id}"

    # Отправляем событие об успешном обновлении настроек
    cable_ready[channel].dispatch_event(
      name: "settingsUpdated",
      detail: {
        message: I18n.t("settings.updated")
      }
    )

    cable_ready[channel].broadcast

    Rails.logger.info("SettingBroadcaster: Sent setting update for user #{user.id}")
  rescue StandardError => e
    Rails.logger.error("SettingBroadcaster error: #{e.class} #{e.message}")
  end
end
