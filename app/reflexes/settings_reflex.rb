# frozen_string_literal: true

require_dependency 'ui/toast_component'

class SettingsReflex < ApplicationReflex

  #
  # Обновляет настройки через Reflex (WebSocket)
  # После сохранения отправляет toast-уведомление
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

    # Отправляем toast об успешном сохранении
    toast_html = ApplicationController.render(
      Ui::ToastComponent.new(
        message: t('settings.updated'),
        type: :success,
        dismissible: true,
        auto_dismiss: 3000
      ),
      layout: false
    )

    cable_ready["user_#{current_user.id}"].insert_adjacent_html(
      selector: "#notifications",
      position: "beforeend",
      html: toast_html
    )

    cable_ready["user_#{current_user.id}"].broadcast
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("SettingsReflex#update not authorized: #{e.class} #{e.message}")

    error_html = ApplicationController.render(
      Ui::ToastComponent.new(
        message: t('settings.update_error'),
        type: :error,
        dismissible: true,
        auto_dismiss: 5000
      ),
      layout: false
    )

    cable_ready["user_#{current_user.id}"].insert_adjacent_html(
      selector: "#notifications",
      position: "beforeend",
      html: error_html
    )

    cable_ready["user_#{current_user.id}"].broadcast
  rescue StandardError => e
    Rails.logger.error("SettingsReflex#update error: #{e.class} #{e.message}")

    error_html = ApplicationController.render(
      Ui::ToastComponent.new(
        message: t('settings.update_error'),
        type: :error,
        dismissible: true,
        auto_dismiss: 5000
      ),
      layout: false
    )

    cable_ready["user_#{current_user.id}"].insert_adjacent_html(
      selector: "#notifications",
      position: "beforeend",
      html: error_html
    )

    cable_ready["user_#{current_user.id}"].broadcast
  end
end
