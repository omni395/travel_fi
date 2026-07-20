# frozen_string_literal: true

#
# Poi::FiltersComponent — адаптивный компонент фильтрации POI
#
# Содержит: поиск (live search) + мультиселект категорий (Ransack) + кнопка сброса
#
# Варианты отображения:
#   :sidebar — внутри сайдбара, flex-col (2 строки: поиск + [категории|сброс])
#   :overlay  — на карте, absolute top-4 right-4, flex-row (горизонтально)
#
# Все категории выбраны по умолчанию.
# Если ни одна категория не выбрана — фильтрация не применяется.
#
# @example (сайдбар)
#   <%= render Poi::FiltersComponent.new(categories: @categories, variant: :sidebar) %>
#
# @example (карта, оверлей)
#   <%= render Poi::FiltersComponent.new(categories: @categories, variant: :overlay) %>
#
class Poi::FiltersComponent < ApplicationComponent
  # @param categories [ActiveRecord::Relation<PoiCategory>] список категорий
  # @param variant [Symbol] :sidebar | :overlay
  def initialize(categories: [], variant: :sidebar)
    @categories = categories
    @variant = variant
  end

  private

  attr_reader :categories, :variant

  #
  # CSS-классы для корневого контейнера (позиционирование + фон)
  #
  # @return [String]
  #
  def container_classes
    case variant
    when :overlay
      "absolute top-4 right-4 z-40 max-w-lg"
    else
      ""
    end
  end

  #
  # CSS-классы для layout (flex-direction)
  #
  # :sidebar — flex-col (2 строки: поиск + [категории|сброс])
  # :overlay — flex-row (горизонтально: [поиск] [категории] [сброс])
  #
  # @return [String]
  #
  def layout_classes
    case variant
    when :overlay
      "flex flex-row items-center gap-1"
    else
      "flex flex-col gap-1"
    end
  end
end
