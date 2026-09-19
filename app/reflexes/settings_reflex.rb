# frozen_string_literal: true

class SettingsReflex < ApplicationReflex
  #
  # Инвертирует булевый параметр настройки текущего пользователя (через WebSocket).
  #
  # Поле приходит в args-параметрах (неймспейсный ключ, без id) как
  # `this.stimulate('SettingsReflex#update', { field: 'my_poi_status_email_enabled' })`.
  # Новое значение берём из актуального состояния БД (SettingService.toggle),
  # а НЕ из aria-checked или dataset клиента — клиентская строка ненадёжна.
  #
  # Reflex НЕ рендерит тосты напрямую — тост доставляется через broadcast
  # (ToastBroadcaster, user_N), а не локальным рендером Ui::ToastComponent
  # (принцип «тосты только через broadcast», ROADMAP 3.2).
  #
  def update
    morph :nothing

    field = params[:field].to_s
    setting = current_user.setting || current_user.create_setting!
    authorize setting, :update?

    new_value = SettingService.toggle(setting, field)
    return send_error_toast unless new_value

    # Точечно обновляем aria-checked у переключателя (селектор по data-field-value),
    # иначе при morph :nothing визуальное состояние осталось бы старым.
    cable_ready.set_attribute(
      selector: "[data-field-value='#{field}']",
      name: "aria-checked",
      value: new_value
    )
    cable_ready.broadcast

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
