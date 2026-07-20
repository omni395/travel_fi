# frozen_string_literal: true

#
# Admin::PoiCategories::PoiCategory::EditComponent - форма редактирования категории POI
#
# @param category [PoiCategory] категория для редактирования
#
class Admin::PoiCategories::PoiCategory::EditComponent < ApplicationComponent
  def initialize(category:)
    @category = category
  end

  private

  attr_reader :category

  #
  # Доступные локали для перевода
  #
  # @return [Array<String>]
  #
  def locales
    %w[en ru es zh]
  end

  #
  # Возвращает значение локализованного поля для указанной локали
  #
  # @param field [Symbol] поле (:name, :description)
  # @param locale [String] код локали
  # @return [String]
  #
  def localized_value(field, locale)
    val = category.public_send(field)
    val.is_a?(Hash) ? val[locale].to_s : val.to_s
  end
end
