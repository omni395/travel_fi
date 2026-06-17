# frozen_string_literal: true

#
# Ui::ConfirmDialogComponent - модальное окно подтверждения действия
#
# Используется вместо нативного `data: { turbo_confirm: }`.
# Поддерживает:
# - Заголовок и сообщение
# - Кастомный текст кнопок
# - Варианты кнопки подтверждения: danger (красная), primary (зелёная)
# - HTTP-метод для подтверждения (get, post, patch, delete)
# - Управление через Stimulus контроллер ui--confirm-dialog-component
#
# Использование:
#   <%= render Ui::ConfirmDialogComponent.new(
#     title: t(".delete_title"),
#     message: t(".delete_message"),
#     confirm_text: t(".delete"),
#     cancel_text: t(".cancel"),
#     confirm_variant: :danger,
#     confirm_url: admin_user_path(user),
#     confirm_method: :delete
#   ) %>
#
class Ui::ConfirmDialogComponent < ApplicationComponent
  attr_reader :title, :message, :confirm_text, :cancel_text, :confirm_variant, :confirm_url, :confirm_method, :dialog_id

  VARIANTS = %i[danger primary].freeze

  #
  # @param title [String] заголовок диалога
  # @param message [String] сообщение диалога
  # @param confirm_text [String] текст кнопки подтверждения
  # @param cancel_text [String] текст кнопки отмены
  # @param confirm_variant [Symbol] :danger (красная) или :primary (teal)
  # @param confirm_url [String] URL для перехода при подтверждении
  # @param confirm_method [Symbol] HTTP-метод (:get, :post, :patch, :delete)
  #
  def initialize(title:, message:, confirm_text: "Confirm", cancel_text: "Cancel",
                 confirm_variant: :danger, confirm_url: nil, confirm_method: :get)
    @title = title
    @message = message
    @confirm_text = confirm_text
    @cancel_text = cancel_text
    @confirm_variant = VARIANTS.include?(confirm_variant) ? confirm_variant : :danger
    @confirm_url = confirm_url
    @confirm_method = confirm_method
    @dialog_id = "confirm-dialog-#{SecureRandom.hex(4)}"
  end

  #
  # CSS класс для кнопки подтверждения в зависимости от варианта
  #
  # @return [String]
  #
  def confirm_button_class
    base = "px-4 py-2 rounded-lg text-sm font-semibold text-white transition-colors"
    case confirm_variant
    when :danger
      "#{base} bg-red-600 hover:bg-red-700"
    when :primary
      "#{base} bg-teal-600 hover:bg-teal-700"
    end
  end

  #
  # CSS класс для кнопки отмены
  #
  # @return [String]
  #
  def cancel_button_class
    "px-4 py-2 rounded-lg text-sm font-semibold text-gray-700 bg-gray-100 hover:bg-gray-200 transition-colors"
  end
end
