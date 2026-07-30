# frozen_string_literal: true

#
# Модель POI (Point of Interest)
# Единая таблица для всех точек интереса с динамическими полями в metadata
# Категория определяет набор доступных полей через poi_category_fields
#
# @attr name [String] название точки
# @attr description [Text] описание
# @attr osm_id [Integer, nil] ID из OpenStreetMap (null если добавлен вручную)
# @attr poi_category_id [Integer] ссылка на категорию
# @attr coordinates [RGeo::Geographic::SphericalPointImpl] географические координаты (PostGIS)
# @attr address [String] адрес
# @attr city [String] город
# @attr country [String] страна
# @attr zip_code [String] почтовый индекс
# @attr status [Integer] статус: 0=pending, 1=approved, 2=rejected, 3=archived
# @attr user_id [Integer] создатель
# @attr rating [Decimal] рейтинг (0.0 - 5.0)
# @attr metadata [Hash] динамические поля категории (JSONB)
# @attr phone [String] телефон
# @attr website [String] веб-сайт
# @attr wheelchair_accessible [Boolean] доступность для инвалидных колясок
# @attr opening_hours [Hash] часы работы в OSM-формате
# @attr price_info [String] информация о ценах
# @attr verification_count [Integer] количество подтверждений
# @attr last_verified_at [DateTime] дата последнего подтверждения
# @attr slug [String] уникальный идентификатор для URL
#
class Poi < ApplicationRecord
  extend FriendlyId
  friendly_id :name, use: :slugged

  # PaperTrail - аудит всех изменений POI
  has_paper_trail

  # Ассоциации
  belongs_to :poi_category
  belongs_to :user
  has_many :poi_comments, dependent: :destroy

  # Enum для статусов
  enum :status, {
    pending: 0,
    approved: 1,
    rejected: 2,
    archived: 3
  }, validate: true

  # Enum для источника: OSM или ручное создание
  enum :source, {
    manual: "manual",
    osm: "osm"
  }, validate: true

  # Валидации
  validates :name, presence: true, length: { minimum: 2, maximum: 200 }
  validates :coordinates, presence: true
  validates :slug, presence: true, uniqueness: true
  validates :rating, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 5 }, allow_nil: true
  validates :osm_id, uniqueness: { allow_nil: true, message: I18n.t("activerecord.errors.models.poi.attributes.osm_id.taken") }

  # Скоупы
  scope :approved, -> { where(status: :approved) }
  scope :pending, -> { where(status: :pending) }
  scope :recent, -> { order(created_at: :desc) }

  # Скоуп: видимые на карте (approved + только из активных категорий)
  scope :visible, -> {
    joins(:poi_category).where(status: :approved, poi_categories: { active: true })
  }

  # PostGIS: POI в радиусе N метров от точки
  scope :within_meters, ->(lat, lng, meters) {
    where(
      "ST_DWithin(coordinates, ST_MakePoint(:lng, :lat)::geography, :meters)",
      lat: lat, lng: lng, meters: meters
    )
  }

  # PostGIS: POI в пределах прямоугольника (границы видимой области карты)
  scope :within_bounds, ->(sw_lat, sw_lng, ne_lat, ne_lng) {
    where(
      "ST_Within(coordinates::geometry, ST_MakeEnvelope(:sw_lng, :sw_lat, :ne_lng, :ne_lat, 4326))",
      sw_lat: sw_lat, sw_lng: sw_lng, ne_lat: ne_lat, ne_lng: ne_lng
    )
  }

  scope :by_category, ->(category_id) { where(poi_category_id: category_id) }
  scope :verified, -> { where("verification_count > 0") }

  #
  # Возвращает локализованное название POI для текущей локали
  # Если перевод для текущей локали отсутствует — возвращает en
  # Если name не Hash (строка) — возвращает как есть
  # Если все fallback'и пусты — возвращает пустую строку
  #
  # @return [String] название на текущем языке
  #
  def localized_name
    return name.to_s unless name.is_a?(Hash)
    name[I18n.locale.to_s].presence ||
      name["en"].presence ||
      name.values.first ||
      name.to_s
  end

  #
  # Возвращает локализованное описание POI для текущей локали
  #
  # @return [String, nil]
  #
  def localized_description
    return nil unless description.is_a?(Hash)
    description[I18n.locale.to_s] || description["en"]
  end

  #
  # Проверяет, на каких языках не заполнены name/description
  # Используется в админке для отображения алерта о неполных переводах
  #
  # @return [Array<Symbol>] список локаль без перевода
  #
  def missing_translations
    I18n.available_locales.select do |locale|
      next true if name.is_a?(Hash) && name[locale.to_s].blank?
      next true if description.is_a?(Hash) && description[locale.to_s].blank?
      false
    end
  end

  #
  # Есть ли незаполненные переводы?
  #
  # @return [Boolean]
  #
  def missing_translations?
    missing_translations.any?
  end

  #
  # Возвращает значение динамического поля из metadata
  #
  # @param field_key [String] ключ поля (например "operator_names")
  # @return [Object, nil] значение поля
  #
  def field_value(field_key)
    metadata[field_key]
  end

  #
  # Устанавливает значение динамического поля в metadata
  #
  # @param field_key [String] ключ поля
  # @param value [Object] значение
  #
  def set_field_value(field_key, value)
    self.metadata = metadata.merge(field_key => value)
  end

  #
  # Возвращает широту
  # Парсит из WKT-строки (POINT(lng lat)) если нет RGeo
  #
  # @return [Float, nil]
  #
  def latitude
    return coordinates.y if coordinates.respond_to?(:y)

    parse_coordinate_from_wkt(1)
  end

  #
  # Возвращает долготу
  # Парсит из WKT-строки (POINT(lng lat)) если нет RGeo
  #
  # @return [Float, nil]
  #
  def longitude
    return coordinates.x if coordinates.respond_to?(:x)

    parse_coordinate_from_wkt(0)
  end

  private

  #
  # Парсит координату из WKT строки вида "POINT (lng lat)"
  #
  # @param index [Integer] 0 для lng, 1 для lat
  # @return [Float, nil]
  #
  def parse_coordinate_from_wkt(index)
    return nil unless coordinates.is_a?(String)

    match = coordinates.match(/POINT\s*\(([^)]+)\)/)
    return nil unless match

    parts = match[1].split(/\s+/)
    parts[index]&.to_f
  end

  #
  # Ransack 4.x — разрешённые атрибуты для поиска
  #
  # @param auth_object [Object, nil]
  # @return [Array<String>]
  #
  def self.ransackable_attributes(auth_object = nil)
    %w[name description city country status source rating verification_count created_at updated_at]
  end

  #
  # Ransack 4.x — разрешённые ассоциации для поиска
  #
  # @param auth_object [Object, nil]
  # @return [Array<String>]
  #
  def self.ransackable_associations(auth_object = nil)
    %w[poi_category user]
  end
end
