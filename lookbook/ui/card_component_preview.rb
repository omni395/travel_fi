# lookbook/ui/card_component_preview.rb
# frozen_string_literal: true

# @logical_path ui
# @component Ui::CardComponent
class Ui::CardComponentPreview < Lookbook::Preview
  # Базовая карточка со всеми слотами (Header, Body, Footer)
  #
  # @param title text "Заголовок"
  # @param body_text text "Основной текст"
  def default(title: "Профиль пользователя", body_text: "Информация о пользователе и его текущем статусе в системе.")
    render_with_template(locals: { title: title, body_text: body_text })
  end

  # Карточка только с кузовом (Body)
  #
  # @param body_text text "Текст внутри карточки"
  def body_only(body_text: "Простая карточка, содержащая только основной блок с контентом.")
    render_with_template(locals: { body_text: body_text })
  end
end