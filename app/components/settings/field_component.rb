# frozen_string_literal: true

#
# Settings::FieldComponent - компонент строки настройки уведомлений
#
# Отображает одну группу настроек (тип события) с тремя переключателями:
# - In-App уведомления (teal)
# - Email уведомления (blue)
# - Push уведомления (amber)
#
# @param setting [Setting] объект настроек пользователя
# @param event_type [String] тип события (e.g. "new_registration", "active_user")
#
class Settings::FieldComponent < ApplicationComponent
  def initialize(setting:, event_type:)
    @setting = setting
    @event_type = event_type
  end

  private

  attr_reader :setting, :event_type

  #
  # Имя поля для in-app уведомлений
  #
  # @return [String] имя поля в БД
  #
  def notifications_field
    "#{event_type}_notifications_enabled"
  end

  #
  # Имя поля для email уведомлений
  #
  # @return [String] имя поля в БД
  #
  def email_field
    "#{event_type}_email_enabled"
  end

  #
  # Имя поля для push уведомлений
  #
  # @return [String] имя поля в БД
  #
  def push_field
    "#{event_type}_push_enabled"
  end

  #
  # Проверяет включена ли настройка
  #
  # @param field [String] имя поля
  # @return [Boolean]
  #
  def enabled?(field)
    setting.public_send(field)
  rescue NoMethodError
    false
  end

  #
  # i18n ключ для заголовка группы настроек
  #
  # @return [String] переведённое название типа события
  #
  def field_label
    t("settings.field_types.#{event_type}")
  end
end
