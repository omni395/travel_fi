# frozen_string_literal: true

#
# Ui::TooltipComponent — универсальный тултип-контейнер / всплывающий оверлей.
#
# Зафиксированные слоты (Sidecar Standard):
#   - trigger_element: элемент, вызывающий показ (кнопка, иконка, элемент карты)
#   - popover: выпадающее содержимое (текст, HTML или вложенные компоненты вроде Ui::CardComponent)
#
# @example 1. Простая текстовая подсказка:
#   <%= render Ui::TooltipComponent.new(text: "Нажмите для копирования") do |t| %>
#     <% t.with_trigger_element { button_tag("Копировать") } %>
#   <% end %>
#
# @example 2. Инжект слотов (например, с Ui::CardComponent):
#   <%= render Ui::TooltipComponent.new(position: :bottom) do |t| %>
#     <% t.with_trigger_element { content_tag(:span, "Инфо") } %>
#     <% t.with_popover { render Ui::CardComponent.new } %>
#   <% end %>
#
# @example 3. Режим карты OpenLayers (BEM-карточка под JS):
#   <%= render Ui::TooltipComponent.new(map_overlay: true) %>
#
# @param text [String, nil] простой текст для быстрых подсказок
# @param position [:top, :bottom, :left, :right] позиционирование
# @param trigger_event [:hover, :click] событие показа
# @param map_overlay [Boolean] режим плавающего оверлея OpenLayers
#
class Ui::TooltipComponent < ApplicationComponent
  renders_one :trigger_element
  renders_one :popover

  POSITION_CLASSES = {
    top: "bottom-full left-1/2 -translate-x-1/2 mb-2",
    bottom: "top-full left-1/2 -translate-x-1/2 mt-2",
    left: "right-full top-1/2 -translate-y-1/2 mr-2",
    right: "left-full top-1/2 -translate-y-1/2 ml-2"
  }.freeze

  def initialize(text: nil, position: :top, trigger_event: :hover, map_overlay: false)
    @text = text
    @position = position.to_sym
    @trigger_event = trigger_event.to_sym
    @map_overlay = map_overlay
  end

  private

  attr_reader :text, :position, :trigger_event, :map_overlay

  def position_class
    POSITION_CLASSES.fetch(position, POSITION_CLASSES[:top])
  end

  def trigger_data_action
    if trigger_event == :click
      "click->ui--tooltip-component--tooltip-component#toggle"
    else
      "mouseenter->ui--tooltip-component--tooltip-component#show mouseleave->ui--tooltip-component--tooltip-component#hide"
    end
  end
end
