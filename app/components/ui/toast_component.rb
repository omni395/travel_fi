# frozen_string_literal: true

#
# Ui::ToastComponent - компонент для отображения всплывающих уведомлений (тостов)
#
class Ui::ToastComponent < ApplicationComponent
  TYPES = {
    success: "bg-teal-600",
    error: "bg-red-600",
    warning: "bg-amber-600",
    info: "bg-blue-600"
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

  def bg_color
    TYPES.fetch(@type, TYPES[:info])
  end
end
