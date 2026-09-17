# frozen_string_literal: true

# @logical_path ui
# @component Ui::ConfirmDialogComponent
class Ui::ConfirmDialogComponentPreview < Lookbook::Preview
  # 1. Диалог по умолчанию (Универсальный: Подтвердить / Отменить)
  def default
    render_with_template
  end

  # 2. Опасное действие (Да / Нет)
  def danger_yes_no
    render_with_template
  end

  # 3. Кастомные кнопки (ОК / Отмена)
  def custom_ok_cancel
    render_with_template
  end
end