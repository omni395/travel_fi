# frozen_string_literal: true

#
# ReverseGeocodingService — определение адреса по координатам через Nominatim (OSM)
#
# Бесплатный сервис без API-ключа.
# Лимит: 1 запрос в секунду.
#
# @example
#   result = ReverseGeocodingService.reverse_geocode(lat: 51.5074, lng: -0.1278)
#   # => { country: "United Kingdom", city: "London", address: "..., ..., ...", zip_code: "..." }
#
class ReverseGeocodingService
  NOMINATIM_URL = "https://nominatim.openstreetmap.org/reverse"
  TIMEOUT = 5

  # Компоненты адреса в порядке приоритета для сборки полного адреса
  ADDRESS_COMPONENTS = %w[
    house_number road pedestrian footway street
    suburb neighbourhood hamlet village
    city_district district state_district
    postcode
  ].freeze

  #
  # Reverse geocoding через Nominatim API
  #
  # @param lat [Float] широта
  # @param lng [Float] долгота
  # @return [Hash, nil] { country:, city:, address:, zip_code: } или nil
  #
  def self.reverse_geocode(lat:, lng:)
    return nil if lat.nil? || lng.nil?

    Rails.logger.info "ReverseGeocodingService: reverse_geocode(#{lat}, #{lng}) — starting"

    uri = URI("#{NOMINATIM_URL}?lat=#{lat}&lon=#{lng}&format=json&addressdetails=1")
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Get.new(uri)
    request["User-Agent"] = "TravelFi/1.0 (reverse-geocoder)"
    request["Accept-Language"] = I18n.locale.to_s

    response = http.request(request)

    unless response.is_a?(Net::HTTPOK)
      Rails.logger.warn "ReverseGeocodingService: HTTP #{response.code}"
      return nil
    end

    data = JSON.parse(response.body)
    return nil if data["error"] || data["address"].nil?

    addr = data["address"] || {}

    # Собираем полный адрес из доступных компонентов
    full_address = build_full_address(addr)

    city = addr["city"].presence ||
           addr["town"].presence ||
           addr["village"].presence ||
           addr["municipality"].presence ||
           addr["county"].presence ||
           addr["state_district"].presence

    result = {
      country: addr["country"].presence,
      city: city,
      address: full_address.presence,
      zip_code: addr["postcode"].presence
    }

    Rails.logger.info "ReverseGeocodingService: reverse_geocode(#{lat}, #{lng}) -> #{result.inspect}"
    result
  rescue Net::ReadTimeout, Net::OpenTimeout
    Rails.logger.warn "ReverseGeocodingService: timeout"
    nil
  rescue JSON::ParserError => e
    Rails.logger.warn "ReverseGeocodingService: JSON parse error: #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.warn "ReverseGeocodingService: error: #{e.message}"
    nil
  end

  #
  # Собирает полный адрес из компонентов Nominatim
  # Включает: дом, улицу, район, квартал, округ (максимум деталей)
  #
  # @param addr [Hash] address компоненты из Nominatim
  # @return [String, nil] собранный адрес
  #
  def self.build_full_address(addr)
    parts = []

    # Улица + дом — основа адреса
    street = addr["road"].presence || addr["pedestrian"].presence || addr["footway"].presence || addr["street"].presence
    house = addr["house_number"].presence

    if street && house
      parts << "#{street}, #{house}"
    elsif street
      parts << street
    elsif house
      parts << house
    end

    # Дополнительные уточнения: корпус, строение, квартира
    parts << addr["building"].presence
    parts << addr["apartment"].presence
    parts << addr["flat"].presence
    parts << addr["unit"].presence
    parts << addr["craft"].presence

    # Район/квартал
    parts << addr["suburb"].presence
    parts << addr["neighbourhood"].presence
    parts << addr["city_district"].presence
    parts << addr["district"].presence
    parts << addr["hamlet"].presence

    result = parts.compact.join(", ")
    result.presence
  end
end
