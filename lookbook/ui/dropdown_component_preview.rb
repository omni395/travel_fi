# frozen_string_literal: true

# @logical_path ui
# @component Ui::DropdownComponent
class Ui::DropdownComponentPreview < Lookbook::Preview
  # 1. Базовое меню с триггером по умолчанию
  def default
    render_with_template
  end

  # 2. Выравнивание (Left, Center, Right)
  def alignments
    render_with_template
  end

  # 3. Меню с иконками и кнопкой Ui::BtnComponent
  def with_icons
    render_with_template
  end

  # 4. Кастомные цвета подложки (Backgrounds)
  def backgrounds
    render_with_template
  end
end
