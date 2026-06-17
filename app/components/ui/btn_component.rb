# frozen_string_literal: true

#
# Ui::BtnComponent - переиспользуемая кнопка
#
# Цвета берутся из @theme (primary, secondary, error и т.д.)
#
# @example
#   <%= render Ui::BtnComponent.new(color: :primary, size: :md) do %>
#     <!-- mdi: content-save -->
#     <i class="mdi mdi-content-save"></i>
#     <%= t('common.save') %>
#   <% end %>
#
# @example
#   <%= render Ui::BtnComponent.new(color: :danger, size: :sm, html: { data: { action: "click->admin--users#destroyUser" } }) do %>
#     <!-- mdi: delete -->
#     <i class="mdi mdi-delete"></i>
#     <%= t('admin.users.destroy') %>
#   <% end %>
#
class Ui::BtnComponent < ApplicationComponent
  # @param color [Symbol] цвет кнопки (:primary, :ghost, :danger, :secondary)
  # @param size [Symbol] размер (:sm, :md, :lg)
  # @param html [Hash] дополнительные HTML атрибуты (data:, class:, id:, type: и т.д.)
  def initialize(color: :primary, size: :md, html: {})
    @color = color.to_s
    @size = size.to_s
    @html = html
  end

  private

  attr_reader :color, :size, :html

  #
  # Собирает полный список CSS классов
  #
  # @return [String] CSS классы
  #
  def css_class
    base = "btn-ui btn-ui--#{color} btn-ui--#{size}"
    base += " #{html[:class]}" if html[:class].present?
    base.strip
  end

  #
  # HTML атрибуты без class (он уже в css_class)
  #
  # @return [Hash] атрибуты
  #
  def attrs
    html.except(:class)
  end
end
