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
  extend FriendlyId
  friendly_id :slug, use: :slugged

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

  #
  # Проверяет, на каких языках не заполнены name/description
  # Используется в админке для отображения алерта о неполных переводах
  #
  # @return [Array<Symbol>] список локаль без перевода
  #
  def missing_translations
    I18n.available_locales.select do |locale|
      next true if name.is_a?(Hash) && name[locale.to_s].blank?
      next true if description.blank?
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
  # Ransack: разрешённые атрибуты для поиска
  #
  # @param auth_object [Object, nil] объект авторизации
  # @return [Array<String>] список разрешённых атрибутов
  #
  def self.ransackable_attributes(auth_object = nil)
    %w[active created_at description icon id name osm_tags osm_default_name position slug updated_at]
  end

  #
  # Ransack: разрешённые ассоциации для поиска
  #
  # @param auth_object [Object, nil] объект авторизации
  # @return [Array<String>] список разрешённых ассоциаций
  #
  def self.ransackable_associations(auth_object = nil)
    %w[poi_category_fields pois]
  end
end
