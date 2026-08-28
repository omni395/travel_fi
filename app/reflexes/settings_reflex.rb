# frozen_string_literal: true

class SettingsReflex < ApplicationReflex
  #
  # Обновляет настройки через Reflex (WebSocket).
  # Reflex НЕ рендерит тосты напрямую — тост доставляется через broadcast
  # (ToastBroadcaster, user_N), а не локальным рендером Ui::ToastComponent
  # (принцип «тосты только через broadcast», ROADMAP 3.2).
  #
  def update
    morph :nothing

    field = element.dataset.fieldValue
    # Текущее состояние из aria-checked (строка "true"/"false"), инвертируем
    current_value = element.aria_checked == "true"
    value = !current_value

    # Авторизация через Pundit
    authorize current_user.setting, :update?

    SettingService.update(current_user.setting, field, value)

    # Тост об успехе — через broadcast (ToastBroadcaster → user_N)
    ToastBroadcaster.call(
      user_id: current_user.id,
      message: t("settings.updated"),
      type: :success,
      auto_dismiss: 3000
    )
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("SettingsReflex#update not authorized: #{e.class} #{e.message}")
    send_error_toast
  rescue StandardError => e
    Rails.logger.error("SettingsReflex#update error: #{e.class} #{e.message}")
    send_error_toast
  end

  private

  #
  # Отправляет тост об ошибке через broadcast (ToastBroadcaster → user_N)
  #
  def send_error_toast
    ToastBroadcaster.call(
      user_id: current_user&.id,
      message: t("settings.update_error"),
      type: :error,
      auto_dismiss: 5000
    )
  end
end
