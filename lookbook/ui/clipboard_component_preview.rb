# lookbook/ui/clipboard_component_preview.rb
# frozen_string_literal: true

# @logical_path ui
# @component Ui::ClipboardComponent
class Ui::ClipboardComponentPreview < Lookbook::Preview
  # 1. Текст берется по умолчанию
  # @param text text "Текст для копирования"
  def default(text: "Копируемый текст по умолчанию")
    render Ui::ClipboardComponent.new(text: text)
  end

  # 2. Копирование прямо переданной ссылки/строки
  # @param text text "Ссылка/строка"
  def with_text(text: "https://example.com/ref/12345")
    render Ui::ClipboardComponent.new(text: text)
  end

  # 3. Копирование из инпута по target_id
  def with_external_target
    render_with_template
  end
end
