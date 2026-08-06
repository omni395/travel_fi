# frozen_string_literal: true

#
# OsmImportService — сервис импорта POI из OpenStreetMap через Overpass API
#
# Ответственность:
# 1. Читает OSM-теги из category.osm_tags (заполняется админом в форме категории)
# 2. Выполняет Overpass QL запрос по bbox из location
# 3. Создаёт POI через PoiService
# 4. Дедуплицирует по osm_id, защищает от затирания пользовательских изменений
#
# @example
#   OsmImportService.call(
#     category: PoiCategory.where.not(osm_tags: []).first,
#     location: { city: "London", country: "United Kingdom", bbox: [51.3, -0.5, 51.7, 0.3] },
#     user: current_user
#   )
#
class OsmImportService
  # Инстансы Overpass API для фолбэка
  OVERPASS_INSTANCES = [
    "https://overpass.openstreetmap.fr/api/interpreter",
    "https://overpass.kumi.systems/api/interpreter",
    "https://overpass-api.de/api/interpreter",
    "https://overpass-turbo.eu/api/interpreter"
  ].freeze

  #
  # Запускает полный цикл импорта POI из OSM (для обратной совместимости)
  #
  # @param category [PoiCategory] категория (должна содержать osm_tags)
  # @param location [Hash] { city: String, country: String, bbox: [south, west, north, east] }
  # @param user [User] создатель POI
  # @return [Hash] статистика { created:, skipped_duplicate:, skipped_modified:, errors: }
  #
  def self.call(category:, location:, user:)
    elements = fetch_elements(category: category, location: location, user: user)
    process_elements(elements: elements, category: category, location: location, user: user)
  end

  #
  # Делает запрос к Overpass API и возвращает элементы
  #
  # @param category [PoiCategory] категория с osm_tags
  # @param location [Hash] { city:, country:, bbox: [s, w, n, e] }
  # @param user [User] пользователь (для User-Agent)
  # @return [Array<Hash>] OSM элементы (node с tags)
  #
  def self.fetch_elements(category:, location:, user:)
    new(category, location, user).send(:fetch_osm_elements)
  end

  #
  # Обрабатывает элементы: создаёт или пропускает POI
  # Принимает блок для колбэка прогресса: |processed_count|
  #
  # @param elements [Array<Hash>] OSM элементы
  # @param category [PoiCategory] категория
  # @param location [Hash] { city:, country: }
  # @param user [User] создатель POI
  # @yield [Integer] количество обработанных элементов
  # @return [Hash] статистика { created:, skipped_duplicate:, skipped_modified:, errors: }
  #
  def self.process_elements(elements:, category:, location:, user:)
    new(category, location, user).send(:process_elements, elements) do |processed|
      yield(processed) if block_given?
    end
  end

  #
  # Полный импорт: fetch + первичный прогресс (найдено/уже в БД) + обработка.
  # Единая точка входа для Reflex — бизнес-логика в Service, а не в Reflex.
  #
  # @param category [PoiCategory] категория с osm_tags
  # @param location [Hash] { city:, country:, bbox: [s, w, n, e] }
  # @param user [User] инициатор импорта
  # @yield [processed, total, already_in_db] колбэк прогресса
  #   (первый вызов: processed=0, already_in_db=N; далее already_in_db=nil)
  # @return [Hash] статистика { created:, skipped_duplicate:, skipped_modified:, errors: }
  #
  def self.import(category:, location:, user:)
    elements = fetch_elements(category: category, location: location, user: user)
    total = elements.size
    fetched_osm_ids = elements.map { |e| e["id"] }.compact
    already_in_db = Poi.where(osm_id: fetched_osm_ids, poi_category_id: category.id).count

    yield(0, total, already_in_db) if block_given?

    process_elements(elements: elements, category: category, location: location, user: user) do |processed|
      yield(processed, total, nil) if block_given?
    end
  end

  attr_reader :category, :location, :user

  def initialize(category, location, user)
    @category = category
    @location = location
    @user = user
  end

  private

  #
  # Валидирует категорию и location
  #
  # @raise [ArgumentError] если osm_tags пусты или bbox невалиден
  #
  def validate!
    unless category.osm_tags.is_a?(Array) && category.osm_tags.any?
      raise ArgumentError, "Category '#{category.slug}' has no OSM tags configured"
    end

    unless location[:bbox].is_a?(Array) && location[:bbox].size == 4
      raise ArgumentError, "Location must include bbox: [south, west, north, east]"
    end
  end

  #
  # Пустая статистика
  #
  def empty_stats
    { created: 0, skipped_duplicate: 0, skipped_modified: 0, errors: 0 }
  end

  #
  # Делает запрос к Overpass API и возвращает элементы
  #
  # @return [Array<Hash>] OSM элементы (node с tags)
  #
  def fetch_osm_elements
    validate!

    tags = category.osm_tags
    south, west, north, east = location[:bbox]

    union = tags.map { |t|
      k, v = t.split("=")
      "nwr[\"#{k}\"=\"#{v}\"](#{south},#{west},#{north},#{east});"
    }.join("\n       ")

    query = <<~OVERPASS
      [out:json][timeout:60];
      (
        #{union}
      );
      out body center;
    OVERPASS

    OVERPASS_INSTANCES.each do |url|
      begin
        uri = URI(url)
        http = Net::HTTP.new(uri.hostname, uri.port)
        http.use_ssl = uri.scheme == "https"
        http.open_timeout = 10
        http.read_timeout = 30
        req = Net::HTTP::Post.new(uri)
        req.set_form_data({ "data" => query })
        req["User-Agent"] = "TravelFi/1.0 (osm-importer)"
        req["Accept"] = "application/json"
        response = http.request(req)

        unless response.is_a?(Net::HTTPOK)
          Rails.logger.warn "OsmImportService: #{url.split('/')[2]}: HTTP #{response.code}"
          next
        end

        data = JSON.parse(response.body)
        elements = (data["elements"] || [])
                   .select { |e| e["tags"] }
                   .reject { |e| e["tags"]["name"].to_s.match?(/^\d+$/) }

        Rails.logger.info "OsmImportService: #{url.split('/')[2]}: #{elements.size} elements"
        return elements
      rescue StandardError => e
        Rails.logger.warn "OsmImportService: #{url.split('/')[2]}: #{e.message}"
      end
    end

    []
  end

  #
  # Обрабатывает элементы: создаёт или пропускает POI с колбэком прогресса
  #
  # @param elements [Array<Hash>] OSM элементы
  # @yield [Integer] количество обработанных элементов (опционально)
  #
  def process_elements(elements)
    stats = { created: 0, skipped_duplicate: 0, skipped_modified: 0, errors: 0 }

    elements.each_with_index do |elem, idx|
      result = create_poi(elem)
      key = result[:status]
      stats[key] = stats[key] + 1 if stats.key?(key)
      yield(idx + 1) if block_given?
    rescue StandardError => e
      stats[:errors] += 1
      Rails.logger.error "OsmImportService: error processing element #{elem['id']}: #{e.message}"
      yield(idx + 1) if block_given?
    end

    stats
  end

  #
  # Создаёт или обновляет POI из элемента OSM
  #
  def create_poi(elem)
    osm_id = elem["id"]
    tags = elem["tags"] || {}
    lat = elem["lat"] || elem.dig("center", "lat")
    lon = elem["lon"] || elem.dig("center", "lon")

    return { status: :skipped_duplicate } if lat.nil? || lon.nil?

    existing = Poi.find_by(osm_id: osm_id)
    if existing
      return { status: :skipped_modified } if modified_by_user?(existing)
      return { status: :skipped_duplicate } unless existing.source == "osm"

      update_existing_poi(existing, elem, tags)
      return { status: :created }
    end

    name = tags["name"].presence || tags["operator"].presence || default_name_for_category
    # Если имя всё ещё короче 2 символов — фолбечим на дефолтное название
    if name.length < 2
      fallback = default_name_for_category
      name = fallback.length >= 2 ? fallback : "Unnamed (#{osm_id})"
    end

    name_hash = { I18n.locale.to_s => name }
    street = [ tags["addr:street"], tags["addr:housenumber"] ].compact.join(" ")

    PoiService.create(
      params: {
        poi_category_id: category.id,
        name: name_hash,
        osm_id: osm_id,
        latitude: lat,
        longitude: lon,
        address: street.presence,
        city: tags["addr:city"].presence || location[:city],
        country: location[:country],
        zip_code: tags["addr:postcode"].presence,
        phone: tags["phone"].presence,
        website: tags["website"].presence,
        wheelchair_accessible: tags["wheelchair"] == "yes",
        price_info: tags["fee"].presence,
        opening_hours: tags["opening_hours"] ? { osm: tags["opening_hours"] } : nil,
        status: :approved,
        source: :osm,
        metadata: tags.except(*%w[name operator phone website wheelchair opening_hours fee
                                  addr:street addr:housenumber addr:city addr:postcode])
                     .compact_blank
      },
      current_user: user
    )

    { status: :created }
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.warn "OsmImportService: validation error for osm_id=#{osm_id}: #{e.message}"
    { status: :skipped_duplicate }
  end

  #
  # Проверяет, вносил ли пользователь изменения в точку
  #
  def modified_by_user?(poi)
    return true if poi.verification_count > 0
    return true if poi.updated_at > poi.created_at + 5.seconds

    # Проверка комментариев — если таблицы нет, считаем что изменений не было
    begin
      return true if poi.poi_comments.exists?
    rescue ActiveRecord::StatementInvalid
      # Таблица poi_comments может отсутствовать (миграция не накачена)
    end

    false
  end

  #
  # Обновляет существующую OSM-точку свежими данными
  #
  def update_existing_poi(poi, elem, tags)
    name = tags["name"].presence || tags["operator"].presence || default_name_for_category
    if name.length < 2
      fallback = default_name_for_category
      name = fallback.length >= 2 ? fallback : "Unnamed (#{poi.osm_id || elem['id']})"
    end

    name_hash = poi.name.is_a?(Hash) ? poi.name.merge(I18n.locale.to_s => name) : { I18n.locale.to_s => name }

    PoiService.update(
      poi: poi,
      params: {
        name: name_hash,
        latitude: elem["lat"],
        longitude: elem["lon"],
        address: [ tags["addr:street"], tags["addr:housenumber"] ].compact.join(" ").presence || poi.address,
        phone: tags["phone"].presence || poi.phone,
        website: tags["website"].presence || poi.website,
        opening_hours: tags["opening_hours"] ? { osm: tags["opening_hours"] } : poi.opening_hours
      },
      current_user: user
    )
  rescue StandardError => e
    Rails.logger.warn "OsmImportService: update error for osm_id=#{elem['id']}: #{e.message}"
  end

  #
  # Возвращает название по умолчанию из настроек категории
  # Если не задано — возвращает "Point of Interest"
  #
  def default_name_for_category
    default_name = category.osm_default_name || {}
    default_name[I18n.locale.to_s].presence ||
      default_name["en"].presence ||
      "Point of Interest"
  end
end
