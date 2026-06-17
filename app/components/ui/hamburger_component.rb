# frozen_string_literal: true

#
# Ui::HamburgerComponent — универсальный компонент гамбургер-меню
#
# Предоставляет выдвижную панель с анимированной кнопкой-бургером,
# поддержкой оверлея, адаптивности и позиционирования слева/справа.
#
# Использование:
#   <%= render Ui::HamburgerComponent.new(position: :left, menu_width_class: "w-72") do |h| %>
#     <% h.with_menu do %>
#       <nav class="p-4"><%= link_to "Home", root_path %></nav>
#     <% end %>
#   <% end %>
#
# С кастомным триггером:
#   <%= render Ui::HamburgerComponent.new do |h| %>
#     <% h.with_trigger do %>
#       <button type="button" class="..."><i class="mdi mdi-menu"></i></button>
#     <% end %>
#     <% h.with_menu do %>
#       ...содержимое...
#     <% end %>
#   <% end %>
#
# @param position [Symbol] :left (по умолч.) или :right — сторона выезда панели
# @param menu_width_class [String] Tailwind-класс ширины панели (по умолч. "w-64")
# @param overlay [Boolean] показывать затемняющий оверлей (по умолч. true)
#
class Ui::HamburgerComponent < ApplicationComponent
  renders_one :trigger
  renders_one :menu

  def initialize(position: :left, menu_width_class: "w-64", overlay: true)
    @position = position
    @menu_width_class = menu_width_class
    @overlay = overlay
  end

  #
  # CSS-класс для позиционирования панели
  # @return [String]
  #
  def panel_position_class
    @position == :right ? "right-0" : "left-0"
  end

  #
  # CSS-класс для анимации выезда (translate)
  # @return [String]
  #
  def panel_translate_class
    @position == :right ? "translate-x-full" : "-translate-x-full"
  end

  #
  # Флаг показа оверлея
  # @return [Boolean]
  #
  def show_overlay?
    @overlay
  end
end
