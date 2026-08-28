# frozen_string_literal: true

class SettingService
  #
  # Обновляет конкретный параметр настройки
  #
  # @param setting [Setting] объект настроек
  # @param field [String/Symbol] имя поля
  # @param value [Boolean] новое значение
  #
  def self.update(setting, field, value)
    return unless setting.respond_to?("#{field}=")

    setting.update!(field => value)
  end
end
