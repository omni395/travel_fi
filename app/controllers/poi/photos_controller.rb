# frozen_string_literal: true

#
# Poi::PhotosController — управление галереей фото POI через HTTP/multipart.
#
# Бинарники фото не передаются через StimulusReflex (WebSocket) — этот
# контроллер решает долг ⚠️ «загрузка фото (бинарники через Reflex) → HTTP/multipart».
# Форма-галерея POSTит файлы сюда; ответ JSON, live-обновление — через Broadcaster
# (PaperTrail → VersionObserverJob → PoiBroadcaster).
#
# Доступ:
# - create:  аутентифицированный пользователь (PhotoPolicy) + антифрод 100м
# - destroy: автор фото / admin / moderator (PhotoPolicy)
#
# Routes: POST/DELETE /pois/:poi_id/photos (см. config/routes.rb)
#
class Poi::PhotosController < ApplicationController
  before_action :authenticate_user!
  before_action :set_poi
  before_action :set_photo, only: [ :destroy ]

  # Контроллер работает с единичным ресурсом через authorize (не коллекциями),
  # поэтому колбэк verify_policy_scoped (глобально из ApplicationController) не
  # применим — иначе каждый POST/DELETE падает с PolicyScopingNotPerformedError
  # (загрузка/удаление фото не работали). Аналог: Admin::PoisController.
  skip_after_action :verify_policy_scoped

  #
  # POST /pois/:poi_id/photos
  #
  # Добавляет фото в галерею (multipart). Антифрод 100м — для не-админов.
  #
  # @return [JSON] { photo: { id:, url:, medium_url:, thumb_url: } } при успехе
  #
  def create
    authorize @poi, :show?

    file = params[:photo][:image] if params[:photo].present?
    return render json: { error: I18n.t("pois.photo_required") }, status: :unprocessable_entity if file.blank?

    # Антифрод 100м: не-админ может добавить фото только находясь рядом с POI.
    unless within_proximity?
      return render json: { error: I18n.t("pois.photo_proximity_error") }, status: :forbidden
    end

    photo = PoiService.add_photo(poi: @poi, file: file, current_user: current_user)
    render json: { photo: photo_json(photo) }, status: :created
  rescue PoiService::CreateError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  #
  # DELETE /pois/:poi_id/photos/:id
  #
  # Удаляет фото из галереи (автор / admin / moderator).
  #
  # @return [JSON] { ok: true } при успехе
  #
  def destroy
    authorize @photo, :destroy?
    # current_user передаём для отзыва награды poi_photo_add, если удаляется
    # собственное фото автора (сервис отзывает только за авторское фото).
    PoiService.remove_photo(poi: @poi, photo_id: @photo.id, current_user: current_user)
    render json: { ok: true }, status: :ok
  rescue PoiService::DestroyError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  private

  #
  # Находит POI по id (для вложенного роута /pois/:poi_id/photos)
  #
  def set_poi
    @poi = Poi.find(params[:poi_id])
  end

  #
  # Находит Photo по id (для destroy)
  #
  def set_photo
    @photo = Photo.find(params[:id])
  end

  #
  # Проверяет проксимити 100м (антифрод) для добавления фото не-админом.
  # Админ/модератор — без ограничений.
  #
  # @return [Boolean]
  #
  def within_proximity?
    PoiService.within_range?(
      user_lat: session[:user_lat],
      user_lng: session[:user_lng],
      poi_lat: @poi.latitude,
      poi_lng: @poi.longitude,
      user: current_user,
      max_meters: PoiService::MAX_INTERACTION_METERS
    )
  end

  #
  # Формирует JSON-представление созданной фото (id + URL вариантов)
  #
  # @param photo [Photo] созданная запись
  # @return [Hash]
  #
  def photo_json(photo)
    {
      id: photo.id,
      url: photo.url(variant: PhotoService::MEDIUM),
      thumb_url: photo.url(variant: PhotoService::THUMB),
      medium_url: photo.url(variant: PhotoService::MEDIUM)
    }
  end
end
