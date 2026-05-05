# frozen_string_literal: true

#
# DropdownComponent - универсальный компонент для выпадающего меню
#
# Использует stimulus-components/dropdown для управления состоянием
# Поддерживает:
# - Произвольный контент в кнопке и меню
# - Позиционирование меню (left, right, center)
# - Анимации переходов
# - Закрытие при клике вне меню
#
# Пример использования:
#
#   <%= render Ui::DropdownComponent.new do |dropdown| %>
#     <% dropdown.with_trigger do %>
#       <button>Options</button>
#     <% end %>
#     <% dropdown.with_menu do %>
#       <a href="#" data-action="dropdown#toggle">Option 1</a>
#       <a href="#" data-action="dropdown#toggle">Option 2</a>
#     <% end %>
#   <% end %>
#
class Ui::DropdownComponent < ApplicationComponent
  renders_one :trigger
  renders_one :menu

  attr_reader :position, :menu_classes

  # Инициализирует компонент
  #
  # @param position [String] позиция меню (left, right, center), по умолчанию right
  # @param menu_classes [String] дополнительные CSS классы для меню
  #
  def initialize(position: "right", menu_classes: "")
    @position = position
    @menu_classes = menu_classes
  end

  # Возвращает CSS класс для позиционирования меню
  #
  # @return [String] CSS класс для позиционирования
  #
  def position_class
    case @position
    when "left"
      "left-0"
    when "center"
      "left-1/2 transform -translate-x-1/2"
    else # right
      "right-0"
    end
  end
end
