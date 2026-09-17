# frozen_string_literal: true

#
# PoiCategoryField - динамическое поле категории POI
#
# Каждое поле определяет специфичный атрибут для сбора данных
# по конкретной категории POI (например, "operator_names" для SIM-киосков)
#
# field_type: string, text, number, boolean, select, multiselect
# label/placeholder/hint - JSONB для хранения переводов на всех языках
# options - JSONB для select/multiselect (массив значений с переводами)
#
class PoiCategoryField < ApplicationRecord
  # PaperTrail - аудит всех изменений полей категорий
  has_paper_trail

  # Ассоциации
  belongs_to :poi_category

  # Скопы
  scope :by_position, -> { order(position: :asc) }

  # Скоуп: активные (включённые) поля категории
  scope :active, -> { where(active: true) }

  # Валидации
  validates :field_key, presence: true, uniqueness: { scope: :poi_category_id }
  validates :field_type, presence: true, inclusion: {
    in: %w[string text number boolean select multiselect]
  }
  validates :label, presence: true
  validates :osm_transform, inclusion: {
    in: [ nil, "boolean", "extract_number", "split_array" ],
    message: :invalid_osm_transform
  }

  #
  # Возвращает локализованную метку поля
  #
  # @return [String] метка на текущем языке или en
  #
  def localized_label
    label[I18n.locale.to_s] || label["en"]
  end

  #
  # Возвращает локализованный placeholder поля
  #
  # @return [String, nil]
  #
  def localized_placeholder
    placeholder&.dig(I18n.locale.to_s) || placeholder&.dig("en")
  end

  #
  # Возвращает локализованную подсказку поля
  #
  # @return [String, nil]
  #
  def localized_hint
    return nil if hint.blank?

    JSON.parse(hint) rescue hint
  end

  #
  # Хелпер: первый (одиночный) OSM-ключ из osm_keys.
  # Упрощает обратную совместимость при указании единственного тега
  # (например, "wheelchair" вместо ["wheelchair"]).
  #
  # @return [String, nil]
  #
  def osm_key
    Array(osm_keys).first
  end

  #
  # Нормализованный массив OSM-ключей (всегда массив).
  # Пустые строки и nil отбрасываются.
  #
  # @return [Array<String>]
  #
  def normalized_osm_keys
    Array(osm_keys).map(&:to_s).reject(&:empty?)
  end

  #
  # Нормализованная карта соответствий OSM-значений (всегда Hash).
  #
  # @return [Hash]
  #
  def normalized_osm_value_map
    osm_value_map.is_a?(Hash) ? osm_value_map : {}
  end
end
