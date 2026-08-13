# frozen_string_literal: true

#
# Admin::Pois::RowComponent - строка таблицы POI
#
# Отображает одну строку в таблице списка POI
# Используется для CableReady морфинга отдельных строк
#
# @param poi [Poi] объект POI для отображения
#
class Admin::Pois::RowComponent < ApplicationComponent
  def initialize(poi:)
    @poi = poi
  end

  private

  attr_reader :poi

  #
  # Возвращает CSS класс для статуса POI
  #
  # @param status [String] статус POI
  # @return [String] CSS класс
  #
  def status_badge_class(status)
    case status.to_s
    when "approved", "imported" then "bg-green-100 text-green-800"
    when "pending" then "bg-yellow-100 text-yellow-800"
    when "rejected" then "bg-red-100 text-red-800"
    when "archived" then "bg-gray-100 text-gray-800"
    else "bg-gray-100 text-gray-800"
    end
  end
end
