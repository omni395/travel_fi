# frozen_string_literal: true

#
# Ui::SidebarComponent — универсальная обёртка сайдбара-оверлея
#
# Сайдбар всегда позиционируется абсолютно поверх контента (flex-поток карты
# не затрагивается), поэтому изменение его состояния НЕ меняет размер карты
# и не вызывает пересчёт границ (bounds) на странице POI.
#
# Состояния:
#   - collapsed (по умолчанию) — узкая полоска с шевроном слева,
#     контент справа занимает всю ширину; перекрытия нет.
#   - expanded — панель раскрывается поверх контента (w-80 + шеврон).
#
# Использование:
#   <%= render Ui::SidebarComponent.new(width_class: "w-80", state: :collapsed) do %>
#     <%= render Poi::SidebarContentComponent.new(pois: @pois) %>
#   <% end %>
#
# Параметры:
#   width_class [String] Tailwind-класс ширины (по умолч. "w-64")
#   state [Symbol] начальное состояние: :collapsed | :expanded
#   extra_controller [String, nil] доп. Stimulus-контроллер (напр. "poi--sidebar-component")
#
class Ui::SidebarComponent < ApplicationComponent
  def initialize(width_class: "w-64", state: :collapsed, extra_controller: nil)
    @width_class = width_class
    @state = state
    @extra_controller = extra_controller
  end

  #
  # Список контроллеров для data-controller
  # @return [String]
  #
  def controller_names
    [ "ui--sidebar-component", @extra_controller ].compact.join(" ")
  end

  #
  # Начальное состояние class-атрибута обёртки (collapsed|expanded)
  # @return [String]
  #
  def state_class
    @state == :expanded ? "ui-sidebar--expanded" : "ui-sidebar--collapsed"
  end
end
