# lookbook/ui/badge_component_preview.rb
# frozen_string_literal: true

# @logical_path ui
# @component Ui::BadgeComponent
class Ui::BadgeComponentPreview < Lookbook::Preview
  # Default Badge Preview
  #
  # @param text text "Текст бейджа"
  # @param color select [primary, secondary, success, warning, error, gray] "Цвет бейджа"
  # @param size select [sm, md] "Размер бейджа"
  def default(text: "Active", color: :primary, size: :md)
    render Ui::BadgeComponent.new(color: color.to_sym, size: size.to_sym) do
      text
    end
  end

  # Все поддерживаемые цвета
  #
  # @param size select [sm, md] "Размер бейджа"
  def all_colors(size: :md)
    colors = %i[primary secondary success warning error gray]
    render_with_template(locals: { colors: colors, size: size })
  end

  # Все поддерживаемые размеры
  #
  # @param color select [primary, secondary, success, warning, error, gray] "Цвет бейджа"
  def all_sizes(color: :primary)
    sizes = %i[sm md]
    render_with_template(locals: { sizes: sizes, color: color })
  end
end
