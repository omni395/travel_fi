# frozen_string_literal: true

#
# Ui::BadgeComponent - переиспользуемый бадж
#
# Цвета берутся из @theme (primary, secondary, success, warning, error, gray)
#
# @example
#   <%= render Ui::BadgeComponent.new(color: :primary, size: :md) do %>
#     <%= t('admin.roles.admin') %>
#   <% end %>
#
# @example
#   <%= render Ui::BadgeComponent.new(color: :success, size: :sm) do %>
#     <%= t('activerecord.attributes.user.statuses.active') %>
#   <% end %>
#
class Ui::BadgeComponent < ApplicationComponent
  # @param color [Symbol] цвет (:primary, :secondary, :success, :warning, :error, :gray)
  # @param size [Symbol] размер (:sm, :md)
  def initialize(color: :gray, size: :md)
    @color = color.to_s
    @size = size.to_s
  end

  private

  attr_reader :color, :size

  #
  # CSS классы для баджа
  #
  # @return [String] CSS классы
  #
  def css_class
    "badge-ui badge-ui--#{color} badge-ui--#{size}"
  end
end
