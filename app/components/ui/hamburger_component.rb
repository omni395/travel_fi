# frozen_string_literal: true

#
# Ui::HamburgerComponent — компонент гамбургер-меню на базе Ui::DropdownComponent
#
# Отображает кнопку-гамбургер и выпадающий списком (dropdown) вместо боковой панели.
#
# Использование:
#   <%= render Ui::HamburgerComponent.new(position: "right") do |h| %>
#     <% h.with_menu do %>
#       <a href="#" class="block px-4 py-2 text-sm text-primary hover:bg-secondary">Home</a>
#     <% end %>
#   <% end %>
#
# @param position [String, Symbol] позиция выпадающего меню (left, right, center), по умолчанию "right"
# @param btn_color [Symbol] цвет кнопки Ui::BtnComponent (:ghost, :primary, :secondary и т.д.)
# @param btn_size [Symbol] размер кнопки Ui::BtnComponent (:sm, :md, :lg)
# @param menu_classes [String] дополнительные CSS-классы для выпадающей плашки
#
class Ui::HamburgerComponent < ApplicationComponent
  renders_one :trigger
  renders_one :menu

  attr_reader :position, :btn_color, :btn_size, :menu_classes

  def initialize(position: "right", btn_color: :ghost, btn_size: :md, menu_classes: "")
    @position = position
    @btn_color = btn_color
    @btn_size = btn_size
    @menu_classes = menu_classes
  end
end
