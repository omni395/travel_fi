# frozen_string_literal: true

#
# Admin::PoiCategoriesController - контроллер для управления категориями POI в админке
#
# Отвечает за:
# - Список категорий с фильтрацией (index)
# - Детальную страницу категории с полями (show)
# - Создание/обновление категорий (create, update)
#
class Admin::PoiCategoriesController < Admin::BaseController
  PER_PAGE = 20

  # Pundit: policy_scope не нужен для create/update/new
  skip_after_action :verify_policy_scoped, only: %i[create update new]

  #
  # Отображает список категорий POI
  #
  def index
    authorize PoiCategory, :index?

    @pagy, @categories = pagy(filtered_categories, limit: PER_PAGE)
  end

  #
  # Отображает форму создания новой категории
  #
  def new
    authorize PoiCategory, :create?

    @category = PoiCategory.new
  end

  #
  # Отображает детальную страницу категории с полями
  #
  def show
    @category = PoiCategory.friendly.find(params[:id])
    authorize @category, :show?

    @edit_mode = params[:edit] == 'true'
    @fields = @category.poi_category_fields.by_position
    @versions = @category.versions.order(created_at: :desc)
    @pagy_audit, @versions = pagy(@versions, limit: 10, page: params[:audit_page] || 1)
  end

  #
  # Создаёт новую категорию POI
  #
  def create
    authorize PoiCategory, :create?

    @category = PoiCategoryService.create(
      params: category_params,
      current_user: current_user
    )

    redirect_to admin_poi_category_path(id: @category), notice: t("admin.poi_categories.create_success")
  rescue PoiCategoryService::CreateError => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  #
  # Обновляет категорию POI
  #
  def update
    @category = PoiCategory.friendly.find(params[:id])
    authorize @category, :update?

    PoiCategoryService.update(
      category: @category,
      params: category_params,
      current_user: current_user
    )

    redirect_to admin_poi_category_path(id: @category), notice: t("admin.poi_categories.update_success")
  rescue PoiCategoryService::UpdateError => e
    flash.now[:alert] = e.message
    render :show, status: :unprocessable_entity
  end

  private

  #
  # Разрешенные параметры для категории
  #
  # @return [ActionController::Parameters]
  #
  def category_params
    params.require(:poi_category).permit(:name, :slug, :icon, :description, :position, :active)
  end

  #
  # Возвращает отфильтрованный список категорий
  #
  # @return [ActiveRecord::Relation]
  #
  def filtered_categories
    categories = PoiCategory.all

    categories = categories.where(active: params[:active]) if params[:active].present?

    if params[:q].present?
      query = "%#{params[:q]}%"
      categories = categories.where("name->>'en' ILIKE ? OR name->>'ru' ILIKE ? OR slug ILIKE ?", query, query, query)
    end

    categories.order(position: :asc)
  end
end
