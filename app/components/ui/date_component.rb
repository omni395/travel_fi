# frozen_string_literal: true

#
# Ui::DateComponent - универсальный компонент для форматирования дат
#
# Формат по умолчанию: DD-MM-YY HH:MM (short)
#
# @example
#   <%= render Ui::DateComponent.new(poi.created_at) %>
#   <%= render Ui::DateComponent.new(user.updated_at, format: :long) %>
#   <%= render Ui::DateComponent.new(nil, fallback: t("common.never")) %>
#
class Ui::DateComponent < ApplicationComponent
  # @param date [DateTime, Date, nil] дата для форматирования
  # @param format [Symbol] формат (:short, :long, :default)
  # @param fallback [String, nil] текст если дата nil
  def initialize(date, format: :short, fallback: nil)
    @date = date
    @format = format
    @fallback = fallback
  end

  private

  attr_reader :date, :format, :fallback

  #
  # Возвращает отформатированную дату или fallback
  #
  # @return [String]
  #
  def formatted
    return fallback || t(".never") unless date.present?

    I18n.l(date, format: format)
  end
end
