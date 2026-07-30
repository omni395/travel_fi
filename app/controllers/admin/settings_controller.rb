# frozen_string_literal: true

#
# Admin::SettingsController - контроллер настроек уведомлений админа
#
# Доступен по маршруту /admin/settings
# Показывает расширенные настройки (все типы событий, включая админские)
# Сохранение через StimulusReflex (SettingsReflex)
# Доступ только для admin/moderator
#
class Admin::SettingsController < Admin::BaseController
  before_action :set_setting

  #
  # Отображает страницу настроек админа
  #
  def show
    authorize @setting, :show?
    @pagy_audit, @versions = pagy(@setting.versions.order(created_at: :desc), limit: 20)
  end

  private

  #
  # Находит или создаёт настройки для текущего админа
  #
  def set_setting
    @setting = current_user.setting || current_user.create_setting!
  end
end
