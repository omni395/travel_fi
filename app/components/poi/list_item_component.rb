# frozen_string_literal: true

#
# Poi::ListItemComponent - элемент списка POI в сайдбаре
#
# Отображает:
# - Иконку категории
# - Название и адрес
# - Рейтинг и статус
# - Popover при наведении через @stimulus-components/popover
#
class Poi::ListItemComponent < ApplicationComponent
  attr_reader :poi

  #
  # @param list_item [Poi] объект POI (параметр коллекции от with_collection)
  #
  def initialize(list_item:)
    @poi = list_item
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
end
