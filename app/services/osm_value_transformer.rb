# frozen_string_literal: true

#
# OsmValueTransformer — маппинг единичного OSM-тега в значение поля категории.
#
# Ответственность:
# 1. По полю категории (PoiCategoryField) и набору сырых OSM-тегов определяет,
#    из какого тега брать значение и как его сконвертировать в тип приложения.
# 2. Приоритет: значение из osm_value_map → трансформация по osm_transform/field_type.
# 3. Возвращает nil, если ни один из osm_keys не найден в тегах (поле не заполняется).
#
# @example
#   OsmValueTransformer.call(field, { "fee" => "yes" })        # => true (boolean)
#   OsmValueTransformer.call(field, { "maxheight" => "2,5m" }) # => 2.5 (extract_number)
#   OsmValueTransformer.call(field, { "currency" => "USD;EUR" }) # => ["USD","EUR"]
#
class OsmValueTransformer
  #
  # Трансформирует сырое значение OSM-тега в значение поля категории.
  #
  # @param field [PoiCategoryField] поле категории с OSM-маппингом
  # @param raw_tags [Hash] сырые OSM-теги { "key" => "value" }
  # @return [Object, nil] сконвертированное значение или nil, если тег не найден
  #
  def self.call(field, raw_tags)
    new(field, raw_tags).transform
  end

  def initialize(field, raw_tags)
    @field = field
    @raw_tags = raw_tags || {}
  end

  #
  # Выполняет маппинг по полю
  #
  # @return [Object, nil]
  #
  def transform
    raw_key = matching_key
    return nil unless raw_key

    raw_val = @raw_tags[raw_key]
    mapped = apply_value_map(raw_val)
    return mapped unless mapped.nil?

    apply_transform(raw_val)
  end

  private

  #
  # Ключи-кандидаты для поиска в OSM-тегах: нормализованный osm_keys
  # или фолбэк на одиночный ключ (osm_key)
  #
  # @return [Array<String>]
  #
  def keys_to_check
    keys = @field.normalized_osm_keys
    keys = [ @field.osm_key ].compact if keys.empty?
    keys
  end

  #
  # Первый из osm_keys, присутствующий в тегах
  #
  # @return [String, nil]
  #
  def matching_key
    keys_to_check.find { |k| @raw_tags.key?(k) }
  end

  #
  # Применяет карту соответствий osm_value_map, если для значения есть запись.
  # Возвращает nil, если ключа в карте нет (nil не сигнализирует «нет значения» —
  # отсутствие ключа проверяется через key?).
  #
  # @param raw_val [Object] сырое значение OSM
  # @return [Object, nil]
  #
  def apply_value_map(raw_val)
    value_map = @field.normalized_osm_value_map
    return value_map[raw_val] if value_map.key?(raw_val)

    nil
  end

  #
  # Применяет трансформацию по osm_transform либо field_type
  #
  # @param raw_val [Object] сырое значение OSM
  # @return [Object]
  #
  def apply_transform(raw_val)
    transform_type = @field.osm_transform.presence || @field.field_type

    case transform_type
    when "boolean"
      boolean_value(raw_val)
    when "extract_number", "number"
      extract_number(raw_val)
    when "split_array", "multiselect"
      split_array(raw_val)
    else
      raw_val
    end
  end

  #
  # Приводит строковый OSM-тег к булеву значению
  #
  # @param raw_val [Object] сырое значение
  # @return [Boolean]
  #
  def boolean_value(raw_val)
    %w[yes true 1 designated].include?(raw_val.to_s.downcase)
  end

  #
  # Извлекает первое число из строки ("2,5m" → 2.5)
  #
  # @param raw_val [Object] сырое значение
  # @return [Float, nil]
  #
  def extract_number(raw_val)
    raw_val.to_s.tr(",", ".").scan(/\d+(?:\.\d+)?/).first&.to_f
  end

  #
  # Разбивает строку по ";" в массив (убирает пустые элементы)
  #
  # @param raw_val [Object] сырое значение
  # @return [Array<String>]
  #
  def split_array(raw_val)
    raw_val.to_s.split(";").map(&:strip).reject(&:empty?)
  end
end
