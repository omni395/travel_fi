# frozen_string_literal: true

#
# Users Controller - контроллер для управления профилями пользователей
#
# Отвечает за:
# - Отображение профиля пользователя (show)
# - Форму редактирования профиля (edit)
# - Обновление профиля пользователя (update, HTTP multipart-форма)
#
# Аватар (бинарный File) через StimulusReflex/WebSocket не передаётся — загрузка
# фото выполняется классическим HTTP multipart-запросом (как в POI-форме).
# Обновление профиля делегируется в UserService (бизнес-логика в Service слое),
# а дамьше срабатывает цепочка PaperTrail → VersionObserverJob → Broadcaster
# (UserBroadcaster + Admin::UserBroadcaster) для live-обновления у подписанных.
#
class UsersController < ApplicationController
  before_action :authenticate_user!
  before_action :set_user
  before_action :authorize_user!

  # Показ, редактирование и обновление работают с единичной записью через
  # Pundit#authorize; policy_scope здесь не нужен — отключаем verify_policy_scoped.
  before_action :skip_policy_scope, only: [ :show, :edit, :update ]

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

  #
  # Обновляет профиль пользователя (HTTP multipart, аватар + имя).
  # Делегирует мутацию в UserService (save! в транзакции). После успешного
  # сохранения PaperTrail триггерит live-обновление; редирект на профиль.
  #
  # PATCH /users/:id
  #
  def update
    UserService.call(user: @user, params: user_params)

    # Редирект на профиль (as-is админская цепочка отдельной формы)
    redirect_to user_path(id: @user), notice: I18n.t("reflexes.user.profile_updated")
  rescue UserService::UpdateError => e
    flash.now[:alert] = e.message
    render :edit, status: :unprocessable_content
  end

  private

  #
  # Находит пользователя по slug или id (FriendlyId)
  #
  def set_user
    @user = User.friendly.find(params[:id])
  end

  #
  # Проверяет права доступа к профилю
  # Использует Pundit для авторизации
  # Для edit проверяется :edit?, для show — :show?, для update — :update?
  #
  def authorize_user!
    action = case action_name
    when "edit" then :edit?
    when "update" then :update?
    else :show?
    end
    authorize @user, action
  end

  #
  # Разрешённые параметры обновления профиля (имя + аватар)
  #
  def user_params
    params.permit(:name, :avatar)
  end
end
