# frozen_string_literal: true

#
# Admin::UsersController - контроллер для управления пользователями в админке
#
# Отвечает за отображение списка пользователей
# Все операции обновления происходят через StimulusReflex
# Доступ только для пользователей с ролями admin или moderator
#
class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: [:select_user, :start_edit, :cancel_edit, :edit]

  PER_PAGE = 20

  #
  # Отображает список пользователей с фильтрацией и поиском
  # Использует Admin::UsersListComponent для реактивного отображения
  #
  def index
    authorize User, :index?

    @search_query = params[:q]
    @status_filter = params[:status]
    @selected_user = nil
    @edit_mode = false
    @roles = Role.all
    @users = filtered_users.order(created_at: :desc).page(params[:page]).per(PER_PAGE)
  end

  #
  # Отображает форму редактирования пользователя
  # Перенаправляет на start_edit для использования StimulusReflex
  #
  def edit
    authorize @user, :update?
    redirect_to select_user_admin_user_path(@user, q: params[:q], status: params[:status])
  end

  #
  # Выбирает пользователя для детального просмотра
  # Используется для морфинга компонента в детальный вид
  #
  def select_user
    authorize @user, :show?

    @search_query = params[:q]
    @status_filter = params[:status]
    @selected_user = @user
    @edit_mode = false
    @roles = Role.all
    @users = filtered_users.order(created_at: :desc).page(params[:page]).per(PER_PAGE)

    render :index
  end

  #
  # Запускает режим редактирования пользователя
  # Используется для морфинга компонента в форму редактирования
  #
  def start_edit
    authorize @user, :update?

    @search_query = params[:q]
    @status_filter = params[:status]
    @selected_user = @user
    @edit_mode = true
    @roles = Role.all
    @users = filtered_users.order(created_at: :desc).page(params[:page]).per(PER_PAGE)

    render :index
  end

  #
  # Отменяет режим редактирования
  # Используется для морфинга компонента в детальный вид
  #
  def cancel_edit
    authorize @user, :show?

    @search_query = params[:q]
    @status_filter = params[:status]
    @selected_user = @user
    @edit_mode = false
    @roles = Role.all
    @users = filtered_users.order(created_at: :desc).page(params[:page]).per(PER_PAGE)

    render :index
  end

  private

  #
  # Находит пользователя по id
  #
  def set_user
    @user = User.find(params[:id])
  end

  #
  # Возвращает отфильтрованный список пользователей
  #
  def filtered_users
    users = User.all

    # Применяем scope из политики
    users = policy_scope(users)

    # Фильтрация по статусу
    users = users.where(status: params[:status]) if params[:status].present?

    # Поиск по имени или email
    if params[:q].present?
      query = "%#{params[:q]}%"
      users = users.where('name LIKE ? OR email LIKE ?', query, query)
    end

    users
  end
end

