# frozen_string_literal: true

#
# Admin::Poi::ShowComponent - детальная страница POI в админке
#
class Admin::Poi::ShowComponent < ApplicationComponent
  attr_reader :poi

  #
  # @param poi [Poi] объект POI
  #
  def initialize(poi:)
    @poi = poi
  end

  #
  # Возвращает CSS класс для статуса
  #
  # @return [String]
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
    locale_names = poi.missing_translations.map { |l| I18n.t("locales.#{l}") }
    I18n.t("admin.poi.show.missing_translations", locales: locale_names.join(", "))
  end
end
