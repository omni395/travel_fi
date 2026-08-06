# frozen_string_literal: true

#
# Admin::PoisController - контроллер для управления POI в админке
#
# Отвечает за:
# - Список POI с фильтрацией (index)
# - Детальную страницу POI (show)
# - Обновление POI (update)
#
class Admin::PoisController < Admin::BaseController
  PER_PAGE = 20

  # Pundit: policy_scope не нужен для create/update/new
  skip_after_action :verify_policy_scoped, only: %i[create update new]

  #
  # Отображает список POI с фильтрацией
  #
  def index
    authorize Poi, :index?

    @pagy, @pois = pagy(filtered_pois, limit: PER_PAGE)
  end

  #
  # Отображает форму создания нового POI
  #
  def new
    authorize Poi, :create?

    @poi = Poi.new
    @categories = PoiCategory.active.by_position
  end

  #
  # Создаёт новый POI
  #
  # POST /admin-panel/pois
  #
  # Дублирует путь Admin::PoisReflex#create для обычного HTTP POST (fallback
  # формы new, если JS/Reflex не сработал). Без этого action маршрут :create
  # указывает на несуществующий метод, и Rails 7.1+ поднимает
  # AbstractController::ActionNotFound для skip_after_action verify_policy_scoped.
  #
  def create
    authorize Poi, :create?

    @poi = PoiService.create(
      params: poi_params,
      current_user: current_user
    )

    redirect_to admin_poi_path(id: @poi), notice: t("admin.pois.create_success")
  rescue PoiService::CreateError => e
    @categories = PoiCategory.active.by_position
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  #
  # Отображает детальную страницу POI
  #
  def show
    @poi = Poi.includes(:poi_category, :user).friendly.find(params[:id])
    authorize @poi, :show?

    @edit_mode = params[:edit] == 'true'
    @categories = PoiCategory.active.by_position
    @versions = @poi.versions.order(created_at: :desc)
    @pagy_audit, @versions = pagy(@versions, limit: 10, page: params[:audit_page] || 1)
  end

  #
  # Обновляет POI
  #
  def update
    @poi = Poi.friendly.find(params[:id])
    authorize @poi, :update?

    PoiService.update(
      poi: @poi,
      params: poi_params,
      current_user: current_user
    )

    redirect_to admin_poi_path(id: @poi), notice: t("admin.pois.update_success")
  rescue PoiService::UpdateError => e
    flash.now[:alert] = e.message
    render :show, status: :unprocessable_entity
  end

  private

  #
  # Разрешенные параметры для POI (включая мультиязычные JSONB поля)
  #
  # @return [ActionController::Parameters]
  #
  def poi_params
    params.require(:poi).permit(
      :poi_category_id, :address, :city, :country,
      :zip_code, :phone, :website, :wheelchair_accessible, :price_info,
      :latitude, :longitude, :status, :opening_hours,
      metadata: {},
      name: I18n.available_locales.map(&:to_s),
      description: I18n.available_locales.map(&:to_s)
    ).tap do |p|
      # Разрешаем name и description как хэш (JSONB)
      p[:name] = params[:poi][:name] if params[:poi][:name].is_a?(ActionController::Parameters)
      p[:description] = params[:poi][:description] if params[:poi][:description].is_a?(ActionController::Parameters)
    end
  end

  #
  # Возвращает отфильтрованный список POI
  #
  # @return [ActiveRecord::Relation]
  #
  def filtered_pois
    pois = Poi.includes(:poi_category, :user)

    pois = pois.where(status: params[:status]) if params[:status].present?
    pois = pois.where(poi_category_id: params[:category_id]) if params[:category_id].present?

    if params[:q].present?
      query = "%#{params[:q]}%"
      pois = pois.where("name ILIKE ? OR address ILIKE ? OR city ILIKE ?", query, query, query)
    end

    pois.order(created_at: :desc)
  end
end
