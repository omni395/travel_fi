# frozen_string_literal: true

#
# PoisController - контроллер для отображения POI на карте
#
# Отвечает за:
# - Главную страницу с картой и списком POI (index)
# - JSON для деталей POI (show)
# - Форму создания нового POI (new)
# - Создание POI (create)
#
class PoisController < ApplicationController
  before_action :authenticate_user!, except: [ :index ]
  before_action :set_poi, only: [ :show ]

  #
  # Отображает карту со списком POI
  #
  # GET /pois
  #
  # NOTE: @pois = Poi.none — список POI загружается через StimulusReflex
  # PoiReflex#load_pois_in_bounds после инициализации карты и при каждом moveend.
  # Это гарантирует, что в сайдбаре отображаются ТОЛЬКО видимые на экране точки.
  #
  def index
    authorize Poi, :index?

    @pois = Poi.none
    @categories = PoiCategory.active.by_position
    @user_lat = session[:user_lat]
    @user_lng = session[:user_lng]

    # Тост для гостей (рендерится через Ui::ToastComponent в лэйауте)
    # У гостей нет ActionCable канала, поэтому flash вместо cable_ready
    unless user_signed_in?
      flash.now[:warning] = t("pois.guest_warning")
    end
  end

  #
  # Перенаправляет на карту POI
  #
  # GET /pois/:id
  #
  def show
    authorize @poi, :show?
    redirect_to pois_path
  end

  #
  # Отображает форму создания POI
  #
  # GET /pois/new
  #
  def new
    authorize Poi, :create?

    @poi = Poi.new
    @categories = PoiCategory.active.by_position
  end

  #
  # Создаёт новый POI
  #
  # POST /pois
  #
  def create
    authorize Poi, :create?

    @poi = PoiService.create(
      params: poi_params,
      current_user: current_user
    )

    redirect_to pois_path, notice: t("pois.create_success")
  rescue PoiService::CreateError => e
    @categories = PoiCategory.active.by_position
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  private

  #
  # Находит POI по id
  #
  def set_poi
    @poi = Poi.find(params[:id])
  end

  #
  # Разрешенные параметры для POI
  #
  # @return [ActionController::Parameters]
  #
  def poi_params
    params.require(:poi).permit(:name, :description, :poi_category_id, :address, :city, :country,
                                :zip_code, :phone, :website, :wheelchair_accessible, :price_info,
                                :latitude, :longitude, metadata: {})
  end
end
