# frozen_string_literal: true

#
# Ui::SidebarComponent — универсальная обёртка сайдбара
#
# Предоставляет:
#   - Flex-контейнер с data-controller="ui--sidebar-component"
#   - Сворачивание/разворачивание (десктоп → 0, мобила → 100vw + оверлей)
#   - Шеврон-кнопку
#
# Использование:
#   <%= render Ui::SidebarComponent.new(width_class: "w-80", extra_controller: "poi--sidebar-component") do %>
#     <%= render Poi::SidebarContentComponent.new(pois: @pois) %>
#   <% end %>
#
# Параметры:
#   width_class [String] Tailwind-класс ширины (по умолч. "w-64")
#   extra_controller [String, nil] доп. Stimulus-контроллер (напр. "poi--sidebar-component")
#
class Ui::SidebarComponent < ApplicationComponent
  def initialize(width_class: "w-64", extra_controller: nil)
    @width_class = width_class
    @extra_controller = extra_controller
  end

  #
  # Список контроллеров для data-controller
  # @return [String]
  #
  def controller_names
    [ "ui--sidebar-component", @extra_controller ].compact.join(" ")
  end
end
