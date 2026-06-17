# frozen_string_literal: true

#
# ToastBroadcaster — отправляет тост-уведомления конкретному пользователю через UserChannel
#
# Ответственность:
# 1. Принимает параметры тоста (сообщение, тип, таймаут)
# 2. Рендерит Ui::ToastComponent в HTML
# 3. Формирует CableReady операцию insert_adjacent_html
# 4. Отправляет в стрим user_N (UserChannel)
#
# Используется из рефлексов и любого места, где нужно показать тост пользователю.
# Не требует StimulusReflex — работает напрямую через ActionCable + CableReady.
#
class ToastBroadcaster
  include CableReady::Broadcaster

  #
  # Отправляет тост пользователю
  #
  # @param user_id [Integer] ID получателя
  # @param message [String] текст тоста
  # @param type [Symbol] тип тоста (:success, :error, :warning, :info)
  # @param dismissible [Boolean] показывать кнопку закрытия
  # @param auto_dismiss [Integer] таймаут авто-скрытия в мс (0 = отключено)
  #
  def self.call(user_id:, message:, type: :info, dismissible: true, auto_dismiss: 5000)
    new(user_id:, message:, type:, dismissible:, auto_dismiss:).broadcast
  end

  attr_reader :user_id, :message, :type, :dismissible, :auto_dismiss

  def initialize(user_id:, message:, type: :info, dismissible: true, auto_dismiss: 5000)
    @user_id = user_id
    @message = message
    @type = type.to_sym
    @dismissible = dismissible
    @auto_dismiss = auto_dismiss
  end

  #
  # Рендерит тост и отправляет через WebSocket в UserChannel
  #
  def broadcast
    html = ApplicationController.render(
      Ui::ToastComponent.new(
        message: message,
        type: type,
        dismissible: dismissible,
        auto_dismiss: auto_dismiss
      ),
      layout: false
    )

    cable_ready["user_#{user_id}"].insert_adjacent_html(
      selector: "#notifications",
      position: "beforeend",
      html: html
    )
    cable_ready["user_#{user_id}"].broadcast

    Rails.logger.info("ToastBroadcaster: Sent toast to user #{user_id} (#{type})")
  rescue StandardError => e
    Rails.logger.error("ToastBroadcaster error: #{e.class} #{e.message}")
  end
end
