# frozen_string_literal: true

#
# PoiService - сервис для управления POI (Points of Interest)
#
# Ответственность:
# 1. Создание/обновление POI
# 2. Изменение статуса POI (модерация)
# 3. Поиск и фильтрация POI
# 4. Геопоиск (nearby)
#
class PoiService
  MAX_INTERACTION_METERS = 100

  # ---
  # Комментарии
  # ---

  #
  # Создаёт комментарий к POI
  #
  # @param poi [Poi] объект POI
  # @param user [User] автор комментария
  # @param body [String] текст комментария
  # @param parent_id [Integer, nil] ID родительского комментария (опционально)
  # @return [PoiComment]
  # @raise [CreateError] если ошибка валидации
  #
  def self.create_comment(poi:, user:, body:, parent_id: nil)
    comment = PoiComment.new(
      poi: poi,
      user: user,
      body: body,
      parent_id: parent_id
    )
    comment.save!
    comment
  rescue ActiveRecord::RecordInvalid => e
    raise CreateError, e.message
  end

  #
  # Обновляет комментарий
  #
  # @param comment [PoiComment] комментарий
  # @param body [String] новый текст
  # @return [PoiComment]
  # @raise [UpdateError] если ошибка валидации
  #
  def self.update_comment(comment:, body:)
    comment.update!(body: body)
    comment
  rescue ActiveRecord::RecordInvalid => e
    raise UpdateError, e.message
  end

  #
  # Удаляет комментарий
  #
  # @param comment [PoiComment] комментарий
  # @raise [DestroyError] если ошибка
  #
  def self.destroy_comment(comment:)
    comment.destroy!
  rescue ActiveRecord::RecordNotDestroyed => e
    raise DestroyError, e.message
  end

  #
  # Проверяет расстояние между пользователем и точкой через PostGIS
  # Админы — без ограничений
  #
  # @param user_lat [Float, nil]
  # @param user_lng [Float, nil]
  # @param poi_lat [Float]
  # @param poi_lng [Float]
  # @param user [User, nil] пользователь для проверки роли (опционально)
  # @param max_meters [Integer]
  # @return [Boolean]
  #
  def self.within_range?(user_lat:, user_lng:, poi_lat:, poi_lng:, user: nil, max_meters: MAX_INTERACTION_METERS)
    return true if user&.has_role?(:admin) || user&.has_role?(:moderator)

    return false if user_lat.nil? || user_lng.nil?
    Poi.connection.select_value(
      Poi.sanitize_sql_array([
        "SELECT ST_DWithin(ST_MakePoint(?, ?)::geography, ST_MakePoint(?, ?)::geography, ?)",
        user_lng, user_lat, poi_lng, poi_lat, max_meters
      ])
    )
  end

  #
  # Создаёт новый POI
  #
  def self.create(params:, current_user:)
    allowed = params.slice(:poi_category_id, :address, :city, :country,
                           :zip_code, :phone, :website, :wheelchair_accessible,
                           :opening_hours, :price_info, :metadata, :osm_id, :status)
    poi = Poi.new(allowed)
    assign_localized_fields(poi, params)
    poi.user = current_user
    poi.coordinates = parse_coordinates(params[:latitude], params[:longitude]) if params[:latitude] && params[:longitude]
    poi.status ||= :pending
    poi.save!

    # Галерея: обрабатываем и прикрепляем фото через PhotoService
    if params[:photos].present?
      PhotoService.attach_photos(record: poi, files: params[:photos], audit_touch: true)
    end

    poi
  rescue ActiveRecord::RecordInvalid => e
    raise CreateError, e.message
  end

  #
  # Обновляет POI
  #
  # @param poi [Poi] POI для обновления
  # @param params [Hash] параметры для обновления
  # @param current_user [User] пользователь, выполняющий обновление
  # @return [Poi] обновленный POI
  # @raise [UpdateError] если произойдет ошибка валидации
  #
  def self.update(poi:, params:, current_user:)
    allowed = params.slice(:poi_category_id, :address, :city, :country,
                           :zip_code, :phone, :website, :wheelchair_accessible,
                           :opening_hours, :price_info, :metadata,
                           :slug, :rating, :status)
    poi.assign_attributes(allowed)
    assign_localized_fields(poi, params)
    if params[:latitude].present? && params[:longitude].present?
      poi.coordinates = parse_coordinates(params[:latitude], params[:longitude])
    end
    poi.save!

    # Галерея: удаляем отмеченные фото и прикрепляем новые через PhotoService
    if params[:remove_photos].present?
      Array(params[:remove_photos]).each do |photo_id|
        PhotoService.remove_photo(record: poi, signed_id: photo_id, audit_touch: true)
      end
    end
    if params[:photos].present?
      PhotoService.attach_photos(record: poi, files: params[:photos], audit_touch: true)
    end

    poi
  rescue ActiveRecord::RecordInvalid => e
    raise UpdateError, e.message
  end

  #
  # Изменяет статус POI (модерация)
  #
  # @param poi [Poi] POI для изменения статуса
  # @param status [String, Symbol] новый статус (:approved, :rejected, :archived)
  # @param current_user [User] пользователь, выполняющий действие
  # @return [Poi] POI с обновленным статусом
  # @raise [StatusError] если произойдет ошибка
  #
  def self.change_status(poi:, status:, current_user:)
    unless %w[approved rejected archived].include?(status.to_s)
      raise StatusError, "Invalid status: #{status}"
    end

    poi.update!(status: status)
    poi
  rescue ActiveRecord::RecordInvalid => e
    raise StatusError, e.message
  end

  #
  # Удаляет POI
  #
  # @param poi [Poi] POI для удаления
  # @param current_user [User] пользователь, выполняющий удаление
  # @raise [DestroyError] если произойдет ошибка
  #
  def self.destroy(poi:, current_user:)
    poi.destroy!
  rescue ActiveRecord::RecordNotDestroyed => e
    raise DestroyError, e.message
  end

  #
  # Ищет POI по запросу через Ransack
  #
  # @param query [String, nil] поисковый запрос
  # @param status [String, nil] фильтр по статусу
  # @param category_id [Integer, nil] фильтр по категории
  # @param sort_column [String, nil] колонка для сортировки
  # @param sort_direction [String, nil] направление сортировки
  # @return [ActiveRecord::Relation] отфильтрованные POI
  #
  def self.search_pois(query: nil, status: nil, category_id: nil, sort_column: nil, sort_direction: nil)
    pois = Poi.includes(:poi_category, :user)

    conditions = {}
    conditions[:name_or_description_cont] = query if query.present?
    conditions[:status_eq] = status if status.present?
    conditions[:poi_category_id_eq] = category_id if category_id.present?

    result = pois.ransack(conditions).result

    if sort_column.present? && %w[name city status rating verification_count created_at updated_at].include?(sort_column)
      direction = sort_direction == 'asc' ? :asc : :desc
      result = result.order(sort_column => direction)
    else
      result = result.order(created_at: :desc)
    end

    result
  end

  #
  # Находит POI рядом с указанными координатами
  #
  # @param lat [Float] широта
  # @param lng [Float] долгота
  # @param radius_km [Integer] радиус поиска в км (по умолчанию 10)
  # @param category_id [Integer, nil] фильтр по категории
  # @return [ActiveRecord::Relation] POI в радиусе
  #
  def self.nearby(lat:, lng:, radius_km: 10, category_id: nil)
    pois = Poi.visible.nearby(lat, lng, radius_km)
    pois = pois.by_category(category_id) if category_id.present?
    pois.order(created_at: :desc)
  end

  #
  # Возвращает GeoJSON для отображения на карте
  #
  # @param pois [ActiveRecord::Relation] список POI
  # @return [Hash] GeoJSON FeatureCollection
  #
  def self.to_geojson(pois)
    {
      type: "FeatureCollection",
      features: pois.map do |poi|
        {
          type: "Feature",
          geometry: {
            type: "Point",
            coordinates: [poi.longitude, poi.latitude]
          },
          properties: {
            id: poi.id,
            name: poi.name,
            slug: poi.slug,
            category: poi.poi_category.localized_name,
            category_slug: poi.poi_category.slug,
            icon: poi.poi_category.icon,
            address: poi.address,
            city: poi.city,
            status: poi.status,
            rating: poi.rating,
            phone: poi.phone,
            website: poi.website,
            wheelchair_accessible: poi.wheelchair_accessible,
            price_info: poi.price_info,
            opening_hours: poi.opening_hours,
            metadata: poi.metadata
          }
        }
      end
    }
  end

  #
  # Строит хэш data-атрибутов фичи карты для скрытого контейнера #poi-map-features.
  # Значения сырые (без экранирования) — экранирование при сборке HTML выполняет Reflex.
  #
  # @param poi [Poi] объект POI
  # @return [Hash] хэш атрибутов: id/lat/lng/name/icon/category/category_id/rating/address/user_id/slug/photo
  #
  def self.map_feature_data(poi)
    {
      id: poi.id,
      lat: poi.latitude,
      lng: poi.longitude,
      name: poi.localized_name.to_s,
      icon: poi.poi_category&.icon.presence || "mdi-map-marker",
      category: poi.poi_category&.localized_name.to_s,
      category_id: poi.poi_category_id,
      rating: poi.rating&.to_f || 0,
      address: [poi.address, poi.city].compact.join(", "),
      user_id: poi.user_id,
      slug: poi.slug,
      photo: PhotoService.cover_photo_url(poi)
    }
  end

  private

  #
  # Устанавливает мультиязычные поля name/description
  # Если значение строка — оборачивает в JSONB для текущей локали
  # Если значение хэш — сохраняет как есть (все локали)
  #
  # @param poi [Poi] объект POI
  # @param params [Hash] параметры
  #
  def self.assign_localized_fields(poi, params)
    if params[:name].present?
      poi.name = if params[:name].is_a?(String)
                   { I18n.locale.to_s => params[:name] }
                 else
                   params[:name]
                 end
    end

    if params[:description].present?
      poi.description = if params[:description].is_a?(String)
                          { I18n.locale.to_s => params[:description] }
                        else
                          params[:description]
                        end
    end
  end

  #
  # Парсит координаты в PostGIS точку
  #
  # @param lat [Float, String] широта
  # @param lng [Float, String] долгота
  # @return [RGeo::Geographic::SphericalPointImpl]
  #
  def self.parse_coordinates(lat, lng)
    factory = RGeo::Geographic.spherical_factory(srid: 4326)
    factory.point(lng.to_f, lat.to_f)
  end

  # Custom exceptions
  class CreateError < StandardError; end
  class UpdateError < StandardError; end
  class StatusError < StandardError; end
  class DestroyError < StandardError; end
end
