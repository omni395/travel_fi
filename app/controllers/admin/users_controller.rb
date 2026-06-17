# frozen_string_literal: true

#
# Admin::UsersController - контроллер для управления пользователями в админке
#
# Отвечает за:
# - Список пользователей с фильтрацией (index)
# - Детальную страницу пользователя (show)
# - Обновление данных пользователя (update)
# Доступ только для пользователей с ролями admin или moderator
#
class Admin::UsersController < Admin::BaseController
  PER_PAGE = 20

  #
  # Отображает список пользователей с фильтрацией и поиском
  #
  def index
    authorize User, :index?

    @search_query = params[:q]
    @status_filter = params[:status]
    @pagy, @users = pagy(filtered_users.order(created_at: :desc), limit: PER_PAGE)
  end

  #
  # Отображает детальную страницу пользователя
  # GET /admin/users/:id
  #
  def show
    @user = User.friendly.find(params[:id])
    authorize @user, :show?

    @edit_mode = params[:edit] == 'true'
    @activities = UserActivityService.new(user: @user).call
    @pagy_audit, @versions = pagy(@user.versions.order(created_at: :desc), limit: 20)
    @roles = Role.all
  end

  #
  # Обновляет данные пользователя
  # PATCH /admin/users/:id
  #
  def update
    @user = User.friendly.find(params[:id])
    authorize @user, :update?

    Admin::UserService.update(
      user: @user,
      params: user_params,
      current_user: current_user
    )

    redirect_to admin_user_path(@user), notice: t('admin.users.update_success')
  rescue Admin::UserService::UpdateError => e
    @edit_mode = true
    @pagy_audit, @versions = pagy(@user.versions.order(created_at: :desc), limit: 20)
    @roles = Role.all
    flash.now[:alert] = e.message
    render :show, status: :unprocessable_entity
  end

  private

  #
  # Разрешенные параметры для обновления пользователя
  #
  # @return [ActionController::Parameters]
  #
  def user_params
    params.require(:user).permit(:name, :email, :status, role_ids: [])
  end

  #
  # Возвращает отфильтрованный список пользователей
  #
  # @return [ActiveRecord::Relation]
  #
  def filtered_users
    users = User.all

    # Применяем scope из политики Admin::UserPolicy
    users = Admin::UserPolicy::Scope.new(current_user, users).resolve

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
