# frozen_string_literal: true

#
# Ui::DropdownComponent - универсальный компонент для выпадающего меню
#
# Поддерживает:
# - Произвольный контент в кнопке (через слот with_trigger) и меню (через слот with_menu)
# - Выравнивание меню (left, right, center)
# - Закрытие при клике вне меню и при выборе пункта
# - Использование встроенной кнопки Ui::BtnComponent по умолчанию
#
# @example
#   <%= render Ui::DropdownComponent.new(position: "right") do |dropdown| %>
#     <% dropdown.with_trigger do %>
#       <%= render Ui::BtnComponent.new(color: :primary) do %>
#         <span><%= t('.actions') %></span>
#         <i class="mdi mdi-chevron-down"></i>
#       <% end %>
#     <% end %>
#     <% dropdown.with_menu do %>
#       <a href="#" data-action="click->ui--dropdown-component#toggle" class="block px-4 py-2 text-sm text-gray-700 hover:bg-gray-100">Action 1</a>
#     <% end %>
#   <% end %>
#
class Ui::DropdownComponent < ApplicationComponent
  renders_one :trigger
  renders_one :menu

  attr_reader :position, :menu_classes

  # Инициализирует компонент
  #
  # @param position [String, Symbol] позиция меню (left, right, center), по умолчанию "right"
  # @param menu_classes [String] дополнительные CSS классы для плашки меню
  #
  def initialize(position: "right", menu_classes: "")
    @position = position.to_s
    @menu_classes = menu_classes
  end

  # Возвращает CSS класс для позиционирования меню
  #
  # @return [String] CSS класс для позиционирования
  #
  def position_class
    case position
    when "left"
      "left-0 origin-top-left"
    when "center"
      "left-1/2 -translate-x-1/2 origin-top"
    else # right
      "right-0 origin-top-right"
    end
  end
end
