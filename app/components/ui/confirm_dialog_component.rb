# frozen_string_literal: true

#
# Ui::ConfirmDialogComponent - модальное окно подтверждения действия
#
# Используется вместо нативного `data: { turbo_confirm: }`.
# Поддерживает:
# - Заголовок и сообщение
# - Кастомный текст кнопок
# - Варианты кнопки подтверждения: danger или primary
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
  # @param title [String, nil] заголовок диалога
  # @param message [String, nil] сообщение диалога
  # @param confirm_text [String, nil] текст кнопки подтверждения (fallback на I18n)
  # @param cancel_text [String, nil] текст кнопки отмены (fallback на I18n)
  # @param confirm_variant [Symbol] :danger или :primary
  # @param confirm_url [String, nil] URL для перехода при подтверждении
  # @param confirm_method [Symbol] HTTP-метод (:get, :post, :patch, :delete)
  # @param dialog_id [String, nil] Явный HTML ID диалога
  #
  def initialize(title: nil, message: nil, confirm_text: nil, cancel_text: nil,
                 confirm_variant: :danger, confirm_url: nil, confirm_method: :get, dialog_id: nil)
    @title = title
    @message = message
    @confirm_text = confirm_text
    @cancel_text = cancel_text
    @confirm_variant = VARIANTS.include?(confirm_variant) ? confirm_variant : :danger
    @confirm_url = confirm_url
    @confirm_method = confirm_method
    @dialog_id = dialog_id.presence || "confirm-dialog-#{SecureRandom.hex(4)}"
  end
end
