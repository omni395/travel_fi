# frozen_string_literal: true

#
# Admin::PoiCategories::PoiCategory::ShowComponent - детальная страница категории POI в админке
#
# Отображает:
# - Алерт о незаполненных переводах
# - Иконку, название, slug, статус
# - Описание
# - Position, количество POI
#
# @param category [PoiCategory] категория POI
#
class Admin::PoiCategories::PoiCategory::ShowComponent < ApplicationComponent
  attr_reader :category

  def initialize(category:)
    @category = category
  end

  #
  # Возвращает сообщение о незаполненных переводах
  #
  # @return [String]
  #
  def missing_translations_message
    I18n.t("admin.poi_categories.poi_category.show_component.missing_translations",
           locales: category.missing_translations.map(&:to_s).join(", "))
  end

  private

  #
  # Проверка на наличие незаполненных переводов
  # Делегируется модели
  #
  def missing_translations?
    category.missing_translations?
  end
end
