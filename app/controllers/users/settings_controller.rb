# frozen_string_literal: true

#
# Users::SettingsController - контроллер настроек уведомлений пользователя
#
# Доступен по маршруту /:id/settings
# Единственный action — show, где пользователь управляет переключателями
# через StimulusReflex (WebSocket). Сохранение + тост.
#
class Users::SettingsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  before_action :set_setting

  #
  # Отображает страницу настроек с переключателями
  #
  def show
    authorize @setting, :show?
  end

  private

  #
  # Находит пользователя по id из params
  #
  def set_user
    @user = User.friendly.find(params[:id])
  end

  #
  # Находит или создаёт настройки для пользователя
  #
  def set_setting
    @setting = @user.setting || @user.create_setting!
  end
end
