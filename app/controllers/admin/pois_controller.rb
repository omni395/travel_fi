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

  #
  # Отображает список POI с фильтрацией
  #
  def index
    authorize Poi, :index?

    @pagy, @pois = pagy(filtered_pois, limit: PER_PAGE)
  end

  #
  # Отображает детальную страницу POI
  #
  def show
    @poi = Poi.includes(:poi_category, :user).find(params[:id])
    authorize @poi, :show?

    @versions = @poi.versions.order(created_at: :desc).limit(20)
  end

  #
  # Обновляет POI
  #
  def update
    @poi = Poi.find(params[:id])
    authorize @poi, :update?

    PoiService.update(
      poi: @poi,
      params: poi_params,
      current_user: current_user
    )

    redirect_to admin_poi_path(@poi), notice: t("admin.pois.update_success")
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
    )
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
