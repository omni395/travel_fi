# frozen_string_literal: true

# @logical_path ui
# @component Ui::FiltersComponent
class Ui::FiltersComponentPreview < Lookbook::Preview
  # 1. Стандартный вариант (Поиск + Селект статусов + Сброс)
  def default
    render_with_template
  end

  # 2. Только поиск без статусов
  def search_only
    render_with_template
  end

  # 3. Сложный вариант со слотами (несколько полей и дропдаунов)
  def with_custom_slots
    render_with_template
  end
end
