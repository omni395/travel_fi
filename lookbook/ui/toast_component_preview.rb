# frozen_string_literal: true

# @logical_path ui
# @component Ui::ToastComponent
class Ui::ToastComponentPreview < Lookbook::Preview
  # Базовый тост
  #
  # @param message text "Сообщение уведомления"
  # @param type select [success, error, warning, info] "Тип уведомления"
  # @param dismissible toggle "Возможность закрытия"
  def default(message: "Операция успешно выполнена!", type: :success, dismissible: true)
    render_with_template(locals: { message: message, type: type, dismissible: dismissible })
  end

  # Все варианты типов тостов
  def all_types
    render_with_template
  end
end
