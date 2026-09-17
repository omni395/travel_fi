# frozen_string_literal: true

#
# Ui::ClipboardComponent - универсальный компонент для копирования текста
#
# Оборачивает целевой текст/элемент с возможностью копирования по клику.
# Можешь передать `text:` напрямую или `target_id:` для копирования содержимого другого элемента.
#
class Ui::ClipboardComponent < ApplicationComponent
  # @param text [String, nil] Явно заданный текст для копирования
  # @param target_id [String, nil] ID элемента на странице (input, div, span), из которого взять текст
  def initialize(text: nil, target_id: nil)
    @text = text
    @target_id = target_id
  end

  private

  attr_reader :text, :target_id
end
