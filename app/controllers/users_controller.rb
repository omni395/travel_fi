# frozen_string_literal: true

#
# Users Controller - контроллер для управления профилями пользователей
#
# Отвечает за:
# - Отображение профиля пользователя (show)
# - Форму редактирования профиля (edit)
#
# Обновление данных происходит через WebSocket (StimulusReflex),
# этот контроллер только рендерит представления
#
class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  before_action :authorize_user!

  #
  # Отображает профиль пользователя
  #
  # GET /users/:id
  #
  def show
    # Профиль рендерится через UserProfileComponent
  end

  #
  # Отображает форму редактирования профиля
  #
  # GET /users/:id/edit
  #
  def edit
    # Форма рендерится через UsersFormComponent
  end

  private

  #
  # Находит пользователя по id
  #
  def set_user
    @user = User.find(params[:id])
  end

  #
  # Проверяет права доступа к профилю
  # Использует Pundit для авторизации
  #
  def authorize_user!
    authorize @user, :show?
  end
end
