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

  #
  # Возвращает список OSM-тегов как строку через запятую
  #
  # @return [String]
  #
  def osm_tags_string
    tags = category.osm_tags
    tags.is_a?(Array) ? tags.join(", ") : tags.to_s
  end

  #
  # URL картинки-маркера категории (или nil, если не прикреплена)
  #
  # @return [String, nil]
  #
  def category_icon_url
    category.category_icon_url
  end

  #
  # URL для загрузки картинки-маркера — member POST
  # /admin-panel/poi_categories/:id/update_category_icon (JSON).
  #
  # @return [String]
  #
  def upload_category_icon_path
    update_category_icon_admin_poi_category_path(id: category)
  end

  #
  # URL для удаления картинки-маркера — member DELETE
  # /admin-panel/poi_categories/:id/remove_category_icon (JSON).
  #
  # @return [String]
  #
  def remove_category_icon_path
    remove_category_icon_admin_poi_category_path(id: category)
  end
end
