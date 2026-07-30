# frozen_string_literal: true

#
# HuggingFaceService — reverse geocoding через HuggingFace Chat API
#
# Использует OpenAI-совместимый endpoint: https://router.huggingface.co/v1/chat/completions
# Модель: openai/gpt-oss-120b:fastest (бесплатная)
#
# @example
#   result = HuggingFaceService.reverse_geocode(lat: 51.5074, lng: -0.1278)
#   # => { country: "United Kingdom", city: "London", address: "..." }
#
class HuggingFaceService
  API_URL = "https://router.huggingface.co/v1/chat/completions"
  MODEL = "openai/gpt-oss-120b:fastest"
  TIMEOUT = 5

  #
  # Reverse geocoding: определяет страну, город и адрес по координатам
  #
  # @param lat [Float] широта
  # @param lng [Float] долгота
  # @return [Hash, nil] { country:, city:, address: } или nil при ошибке
  #
  def self.reverse_geocode(lat:, lng:)
    return nil if api_key.blank?
    return nil if lat.nil? || lng.nil?

    Rails.logger.info "HuggingFaceService: reverse_geocode(#{lat}, #{lng}) — starting"

    uri = URI(API_URL)
    http = Net::HTTP.new(uri.hostname, uri.port)
    http.use_ssl = true
    http.open_timeout = TIMEOUT
    http.read_timeout = TIMEOUT

    request = Net::HTTP::Post.new(uri)
    request["Authorization"] = "Bearer #{api_key}"
    request["Content-Type"] = "application/json"

    messages = [
      { role: "system", content: "You are a geocoding assistant. Return ONLY valid JSON without any other text." },
      { role: "user", content: "Given coordinates (#{lat}, #{lng}), return country, city and street address as JSON: {\"country\": \"...\", \"city\": \"...\", \"address\": \"...\"}" }
    ]

    request.body = {
      model: MODEL,
      messages: messages,
      stream: false,
      max_tokens: 150
    }.to_json

    response = http.request(request)

    unless response.is_a?(Net::HTTPOK)
      Rails.logger.warn "HuggingFaceService: HTTP #{response.code}: #{response.body[0..200]}"
      return nil
    end

    body = JSON.parse(response.body)
    content = body.dig("choices", 0, "message", "content")
    Rails.logger.info "HuggingFaceService: raw response content: #{content&.truncate(300)}"
    return nil unless content

    result = parse_geocode_response(content)

    if result
      Rails.logger.info "HuggingFaceService: reverse_geocode(#{lat}, #{lng}) -> #{result.inspect}"
    else
      Rails.logger.warn "HuggingFaceService: reverse_geocode(#{lat}, #{lng}) — no result"
    end

    result
  rescue Net::ReadTimeout, Net::OpenTimeout
    Rails.logger.warn "HuggingFaceService: timeout"
    nil
  rescue JSON::ParserError => e
    Rails.logger.warn "HuggingFaceService: JSON parse error: #{e.message}"
    nil
  rescue StandardError => e
    Rails.logger.warn "HuggingFaceService: reverse_geocode error: #{e.message}"
    nil
  end

  def self.toxicity_check(text:)
    nil
  end

  private

  def self.parse_geocode_response(content)
    # Пробуем найти JSON с country/city/address
    json_match = content.match(/\{.*"country".*"city".*/m)
    return nil unless json_match

    # Чистим — убираем текст после закрывающей скобки
    json_str = json_match[0]
    # Находим первую полную закрывающую скобку
    end_idx = json_str.index("}")
    json_str = json_str[0..end_idx] if end_idx

    parsed = JSON.parse(json_str)
    {
      country: parsed["country"].presence,
      city: parsed["city"].presence || parsed["town"].presence || parsed["village"].presence,
      address: parsed["address"].presence || parsed["road"].presence || parsed["display_name"].presence
    }
  rescue JSON::ParserError => e
    Rails.logger.warn "HuggingFaceService: JSON parse error: #{e.message}, content: #{content.truncate(200)}"
    nil
  end

  def self.api_key
    ENV["HUGGINGFACE_API_KEY"]
  end
end
