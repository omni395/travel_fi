# frozen_string_literal: true

# @logical_path ui
# @component Ui::TooltipComponent
class Ui::TooltipComponentPreview < Lookbook::Preview
  # Дефолтный интерактивный тултип
  #
  # @param text text "Текст простой подсказки"
  def default(text: "Дефолтный текстовый тултип")
    render_with_template(locals: { text: text })
  end

  # Варианты позиционирования (Top, Bottom, Left, Right)
  def positions
    render_with_template
  end

  # Кастомный слот и инжект Ui::CardComponent
  def with_content_slot
    render_with_template
  end

  # Режим плавающего оверлея OpenLayers
  def map_overlay
    render_with_template
  end
end
