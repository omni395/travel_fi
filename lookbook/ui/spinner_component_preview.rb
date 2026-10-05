# lookbook/ui/spinner_component_preview.rb
# frozen_string_literal: true

# @logical_path ui
# @component Ui::SpinnerComponent
class Ui::SpinnerComponentPreview < Lookbook::Preview
  # Полноэкранный оверлей загрузки (логотип + кольцо + процент)
  def default
    render_with_template
  end
end
