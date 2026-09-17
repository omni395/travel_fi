# frozen_string_literal: true

#
# Admin::Pois::Poi::HeaderComponent - шапка детальной страницы POI в админке
#
# Отображает:
# - Алерт о незаполненных переводах
# - Заголовок (localized_name), категорию, slug, OSM ID
# - Статус-бейдж
# - Кнопку «Редактировать»
#
# @param poi [Poi] объект POI
#
class Admin::Pois::Poi::HeaderComponent < ApplicationComponent
  def initialize(poi:)
    @poi = poi
  end

  private

  attr_reader :poi

  #
  # Возвращает CSS класс для бейджа статуса
  #
  # @return [String] CSS класс
  #
  def status_badge_class
    case poi.status
    when "approved" then "bg-green-100 text-green-800"
    when "pending" then "bg-yellow-100 text-yellow-800"
    when "rejected" then "bg-red-100 text-red-800"
    when "archived" then "bg-gray-100 text-gray-800"
    else "bg-gray-100 text-gray-800"
    end
  end

  #
  # Возвращает сообщение о незаполненных переводах
  #
  # @return [String]
  #
  def missing_translations_message
    I18n.t("admin.pois.poi.show_component.missing_translations",
           locales: poi.missing_translations.map(&:to_s).join(", "))
  end
end
