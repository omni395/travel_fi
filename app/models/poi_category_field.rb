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

  # Валидации
  validates :field_key, presence: true, uniqueness: { scope: :poi_category_id }
  validates :field_type, presence: true, inclusion: {
    in: %w[string text number boolean select multiselect]
  }
  validates :label, presence: true

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
end
