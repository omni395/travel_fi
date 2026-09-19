# frozen_string_literal: true

#
# Admin::GamificationSettingsReflex — обработчик формы настройки геймификации.
#
# При изменении числового поля геймификации админом обновляет
# Setting.global_settings.gamification_config (JSONB) через
# SettingService.update_gamification. Значения подхватываются на лету.
#
class Admin::GamificationSettingsReflex < ApplicationReflex
  #
  # Сохраняет значение числового поля геймификации.
  # Параметры приходят из args: { section: "rewards"|"pool", key:, value: }.
  #
  def update
    morph :nothing

    section = params[:section].to_s
    key = params[:key].to_s
    value = params[:value]

    return send_error unless SettingService.update_gamification(section, key, value)

    ToastBroadcaster.call(
      user_id: current_user.id,
      message: I18n.t("admin.gamification_settings_component.updated"),
      type: :success,
      auto_dismiss: 3000
    )
  rescue Pundit::NotAuthorizedError => e
    Rails.logger.warn("Admin::GamificationSettingsReflex#update not authorized: #{e.message}")
    send_error
  rescue StandardError => e
    Rails.logger.error("Admin::GamificationSettingsReflex#update error: #{e.class} #{e.message}")
    send_error
  end

  private

  #
  # Отправляет тост об ошибке.
  #
  def send_error
    ToastBroadcaster.call(
      user_id: current_user&.id,
      message: I18n.t("settings.update_error"),
      type: :error,
      auto_dismiss: 5000
    )
  end
end
