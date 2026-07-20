# frozen_string_literal: true

#
# Admin::Pois::TableComponent - таблица POI для админки
#
class Admin::Pois::TableComponent < ApplicationComponent
  attr_reader :pois, :pagy

  #
  # @param pois [ActiveRecord::Relation] список POI
  # @param pagy [Pagy, nil] объект пагинации
  #
  def initialize(pois:, pagy: nil)
    @pois = pois
    @pagy = pagy
  end

  #
  # Возвращает CSS класс для статуса
  #
  # @param status [String] статус POI
  # @return [String]
  #
  def status_badge_class(status)
    case status
    when "approved" then "bg-green-100 text-green-800"
    when "pending" then "bg-yellow-100 text-yellow-800"
    when "rejected" then "bg-red-100 text-red-800"
    when "archived" then "bg-gray-100 text-gray-800"
    else "bg-gray-100 text-gray-800"
    end
  end
end
