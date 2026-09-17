# frozen_string_literal: true

#
# OsmPbfImportService — импорт POI из локального файла OpenStreetMap (.osm.pbf)
#
# Ответственность:
# 1. Читает .pbf-файл через OsmPbfParser (стриминг, без загрузки в память)
# 2. Фильтрует точки по category.osm_tags
# 3. Собирает metadata через OsmValueTransformer (см. OsmImportService.build_metadata_for_category)
# 4. Дедуплицирует по osm_id, защищает от затирания пользовательских изменений
# 5. Создаёт POI через PoiService (аудит PaperTrail → VersionObserverJob → Broadcaster)
#
# Файл удаляется вызывающей стороной (OsmPbfImportJob) в ensure.
#
# @example
#   OsmPbfImportService.call(
#     category: category,
#     file_path: "/tmp/region.osm.pbf",
#     user: current_user
#   ) { |processed| ... }
#
class OsmPbfImportService
  #
  # Запускает импорт из .pbf файла
  #
  # @param category [PoiCategory] категория (должна содержать osm_tags)
  # @param file_path [String] абсолютный путь к .osm.pbf файлу
  # @param user [User] создатель POI
  # @yield [Integer] количество обработанных записей (опционально)
  # @return [Hash] статистика { created:, skipped_duplicate:, skipped_modified:, errors: }
  #
  def self.call(category:, file_path:, user:)
    new(category, file_path, user).perform
  end

  def initialize(category, file_path, user)
    @category = category
    @file_path = file_path
    @user = user
  end

  def perform
    stats = { created: 0, skipped_duplicate: 0, skipped_modified: 0, errors: 0 }

    parser.each_record do |record|
      result = process_record(record)
      key = result[:status]
      stats[key] = stats[key] + 1 if stats.key?(key)
      yield(stats.values.sum) if block_given?
    end

    stats
  rescue OsmPbfParser::ToolNotFoundError, OsmPbfParser::ReadError => e
    raise ImportError, e.message
  end

  private

  attr_reader :category, :file_path, :user

  #
  # Создаёт стриминговый парсер .pbf
  #
  # @return [OsmPbfParser]
  #
  def parser
    OsmPbfParser.new(file_path)
  end

  #
  # Обрабатывает одну запись (точку) из PBF
  #
  # @param record [Hash] { id:, lat:, lon:, tags: }
  # @return [Hash] { status: :created | :skipped_duplicate | :skipped_modified }
  #
  def process_record(record)
    tags = record[:tags] || {}

    # 1. Фильтр: тег должен совпадать хотя бы с одним из category.osm_tags
    return { status: :skipped_duplicate } unless matches_category_tags?(tags)

    # 2. Дедупликация по osm_id + защита от затирания
    existing = Poi.find_by(osm_id: record[:id])
    if existing
      return { status: :skipped_modified } if modified_by_user?(existing)
      return { status: :skipped_duplicate } unless existing.source == "osm"

      update_existing_poi(existing, record, tags)
      return { status: :created }
    end

    create_poi(record, tags)
    { status: :created }
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "OsmPbfImportService: validation error for osm_id=#{record[:id]}: #{e.message}"
    { status: :skipped_duplicate }
  rescue StandardError => e
    Rails.logger.error "OsmPbfImportService: error for osm_id=#{record[:id]}: #{e.message}"
    { status: :errors }
  end

  #
  # Проверяет совпадение тегов точки с category.osm_tags (k=v)
  #
  # @param tags [Hash] теги точки
  # @return [Boolean]
  #
  def matches_category_tags?(tags)
    Array(category.osm_tags).any? do |tag_str|
      k, v = tag_str.split("=", 2)
      tags[k] == v
    end
  end

  #
  # Создаёт новый POI из записи PBF
  #
  # @param record [Hash] { id:, lat:, lon:, tags: }
  # @param tags [Hash] теги
  #
  def create_poi(record, tags)
    name = tags["name"].presence || tags["operator"].presence || default_name_for_category
    name = "Unnamed (#{record[:id]})" if name.length < 2

    PoiService.create(
      params: {
        poi_category_id: category.id,
        name: { I18n.locale.to_s => name },
        osm_id: record[:id],
        latitude: record[:lat],
        longitude: record[:lon],
        address: [ tags["addr:street"], tags["addr:housenumber"] ].compact.join(" ").presence,
        city: tags["addr:city"].presence,
        phone: tags["phone"].presence,
        website: tags["website"].presence,
        wheelchair_accessible: tags["wheelchair"] == "yes",
        price_info: tags["fee"].presence || tags["charge"].presence,
        opening_hours: tags["opening_hours"] ? { osm: tags["opening_hours"] } : nil,
        status: :imported,
        source: :osm,
        metadata: build_metadata_for_category(tags)
      },
      current_user: user
    )
  end

  #
  # Обновляет существующую OSM-точку свежими данными (без затирания пользователя)
  #
  # @param poi [Poi] существующая точка
  # @param record [Hash] запись PBF
  # @param tags [Hash] теги
  #
  def update_existing_poi(poi, record, tags)
    name = tags["name"].presence || tags["operator"].presence || default_name_for_category
    name_hash = poi.name.is_a?(Hash) ? poi.name.merge(I18n.locale.to_s => name) : { I18n.locale.to_s => name }

    PoiService.update(
      poi: poi,
      params: {
        name: name_hash,
        latitude: record[:lat],
        longitude: record[:lon],
        address: [ tags["addr:street"], tags["addr:housenumber"] ].compact.join(" ").presence || poi.address,
        phone: tags["phone"].presence || poi.phone,
        website: tags["website"].presence || poi.website,
        opening_hours: tags["opening_hours"] ? { osm: tags["opening_hours"] } : poi.opening_hours,
        metadata: build_metadata_for_category(tags)
      },
      current_user: user
    )
  end

  #
  # Проверяет, вносил ли пользователь изменения в точку
  #
  # @param poi [Poi]
  # @return [Boolean]
  #
  def modified_by_user?(poi)
    return true if poi.verification_count > 0
    return true if poi.updated_at > poi.created_at + 5.seconds

    begin
      return true if poi.poi_comments.exists?
    rescue ActiveRecord::StatementInvalid
      # Таблица poi_comments может отсутствовать (миграция не накачена)
    end

    false
  end

  #
  # Извлекает из OSM-тегов ТОЛЬКО поля, зарегистрированные в poi_category_fields
  #
  # @param tags [Hash] теги
  # @return [Hash] metadata { field_key => значение }
  #
  def build_metadata_for_category(tags)
    result = {}

    category.poi_category_fields.where(active: true).each do |field|
      transformed_val = OsmValueTransformer.call(field, tags)
      result[field.field_key] = transformed_val unless transformed_val.nil?
    end

    result
  end

  #
  # Название по умолчанию из настроек категории
  #
  # @return [String]
  #
  def default_name_for_category
    default_name = category.osm_default_name || {}
    default_name[I18n.locale.to_s].presence ||
      default_name["en"].presence ||
      "Point of Interest"
  end

  # Кастомное исключение импорта
  class ImportError < StandardError; end
end
