# frozen_string_literal: true

#
# Ui::PaginationComponent - компонент пагинации на основе Pagy (v43+)
#
# Рендерит кнопки пагинации вручную с Tailwind-стилями (teal/sky гамма)
# Генерирует series вручную, т.к. Pagy 43.5.1 не имеет встроенного метода series
#
# @example
#   <%= render Ui::PaginationComponent.new(pagy: @pagy) %>
#
class Ui::PaginationComponent < ApplicationComponent
  # @param pagy [Pagy] объект пагинации
  # @param pagination_controller [String] Stimulus контроллер для обработки кликов
  def initialize(pagy:, pagination_controller: "admin--users--table-component")
    @pagy = pagy
    @pagination_controller = pagination_controller
  end

  private
 
  attr_reader :pagy, :pagination_controller

  #
  # Генерирует массив для навигации по страницам
  # Включает номера страниц и :gap для пропусков
  # Аналог pagy.series из старой версии Pagy
  #
  # @return [Array<Integer, Symbol>] массив страниц и :gap
  #
  def series
    current = pagy.page
    total = pagy.pages
    return (1..total).to_a if total <= 7

    result = [1]
    result << :gap if current > 4
    result += ([(current - 1), 2].max..[(current + 1), total - 1].min).to_a
    result << :gap if current < total - 3
    result << total
    result.uniq
  end
end
