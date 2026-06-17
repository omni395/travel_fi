# frozen_string_literal: true

#
# PoiCategory - категория точки интереса
#
# Каждая категория определяет набор динамических полей (PoiCategoryField)
# для сбора специфичных данных по типу POI (SIM-киоски, туалеты, зарядки и т.д.)
#
# Поля name и description - JSONB для хранения переводов на всех языках (en, ru, es, zh)
#
class PoiCategory < ApplicationRecord
  # PaperTrail - аудит всех изменений категорий
  has_paper_trail

  # Ассоциации
  has_many :poi_category_fields, -> { order(position: :asc) }, dependent: :destroy
  has_many :pois, dependent: :restrict_with_error

  # Валидации
  validates :name, presence: true
  validates :slug, presence: true, uniqueness: true

  # Скоупы
  scope :active, -> { where(active: true) }
  scope :by_position, -> { order(position: :asc) }

  #
  # Возвращает локализованное название категории
  #
  # @return [String] название на текущем языке или дефолтное en
  #
  def localized_name
    name[I18n.locale.to_s].presence ||
      name["en"].presence ||
      name.values.first ||
      ""
  end

  #
  # Возвращает локализованное описание категории
  #
  # @return [String, nil] описание на текущем языке или en
  #
  def localized_description
    desc = description || {}
    desc[I18n.locale.to_s] || desc["en"]
  end
end
