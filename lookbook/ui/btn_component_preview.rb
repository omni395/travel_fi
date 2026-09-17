# lookbook/ui/btn_component_preview.rb
# frozen_string_literal: true

# @logical_path ui
# @component Ui::BtnComponent
class Ui::BtnComponentPreview < Lookbook::Preview
  # Default Button
  #
  # @param text text "Текст кнопки"
  # @param color select [primary, secondary, ghost, danger] "Цвет кнопки"
  # @param size select [sm, md, lg] "Размер кнопки"
  def default(text: "Сохранить", color: :primary, size: :md)
    render Ui::BtnComponent.new(color: color.to_sym, size: size.to_sym) do
      text
    end
  end

  # Кнопка с иконкой
  #
  # @param color select [primary, secondary, ghost, danger] "Цвет кнопки"
  # @param size select [sm, md, lg] "Размер кнопки"
  def with_icon(color: :primary, size: :md)
    render_with_template(locals: { color: color, size: size })
  end

  # Все варианты цветов
  #
  # @param size select [sm, md, lg] "Размер кнопки"
  def all_colors(size: :md)
    colors = %i[primary secondary ghost danger]
    render_with_template(locals: { colors: colors, size: size })
  end

  # Все размеры
  #
  # @param color select [primary, secondary, ghost, danger] "Цвет кнопки"
  def all_sizes(color: :primary)
    sizes = %i[sm md lg]
    render_with_template(locals: { sizes: sizes, color: color })
  end
end
