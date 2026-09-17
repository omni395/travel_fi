# frozen_string_literal: true

#
# Ui::ToastComponent - компонент для отображения всплывающих уведомлений (тостов)
#
class Ui::ToastComponent < ApplicationComponent
  TYPES = {
    success: {
      bg: "bg-success text-text border-success",
      icon: "mdi-check-circle-outline"
    },
    error: {
      bg: "bg-error text-text border-error",
      icon: "mdi-alert-circle-outline"
    },
    warning: {
      bg: "bg-warning text-text border-warning",
      icon: "mdi-alert-outline"
    },
    info: {
      bg: "bg-info text-text border-info",
      icon: "mdi-information-outline"
    }
  }.freeze

  #
  # Инициализирует компонент тоста
  #
  # @param message [String] текст уведомления
  # @param type [Symbol] тип тоста (:success, :error, :warning, :info)
  # @param dismissible [Boolean] показывать кнопку закрытия
  # @param auto_dismiss [Integer] таймаут авто-скрытия в мс (0 = отключено)
  #
  def initialize(message:, type: :success, dismissible: true, auto_dismiss: 5000)
    @message = message
    @type = type.to_sym
    @dismissible = dismissible
    @auto_dismiss = auto_dismiss
  end

  private

  def config
    TYPES.fetch(@type, TYPES[:info])
  end

  def bg_classes
    config[:bg]
  end

  def icon_class
    config[:icon]
  end
end
