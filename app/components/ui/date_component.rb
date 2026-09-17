# frozen_string_literal: true

#
# Ui::DateComponent - универсальный компонент для форматирования дат
#
# Формат по умолчанию: DD-MM-YY HH:MM (short)
#
# @example
#   <%= render Ui::DateComponent.new(poi.created_at) %>
#   <%= render Ui::DateComponent.new(user.updated_at, format: :long, badge: true) %>
#   <%= render Ui::DateComponent.new(nil, fallback: t(".never"), badge: true, badge_color: :gray) %>
#
class Ui::DateComponent < ApplicationComponent
  attr_reader :date, :format, :fallback, :badge, :badge_color, :size, :html_class

  FORMATS = %i[short long default date_only time_only relative].freeze

  # @param date [DateTime, Time, Date, nil] дата для форматирования
  # @param format [Symbol] формат (:short, :long, :default, :date_only, :time_only, :relative)
  # @param fallback [String, nil] текст если дата nil
  # @param badge [Boolean] оборачивать ли в Ui::BadgeComponent
  # @param badge_color [Symbol] цвет бейджа (:gray, :primary, :secondary, :success, :warning, :error)
  # @param size [Symbol] размер бейджа/текста (:sm, :md)
  # @param class [String, nil] дополнительные CSS классы
  def initialize(date = nil, format: :short, fallback: nil, badge: false, badge_color: :gray, size: :md, **html_options)
    @date = date
    @format = FORMATS.include?(format.to_sym) ? format.to_sym : :short
    @fallback = fallback
    @badge = badge
    @badge_color = badge_color
    @size = size
    @html_class = html_options[:class] || html_options["class"]
  end

  private

  #
  # Возвращает отформатированную дату или fallback
  #
  # @return [String]
  #
  def formatted
    return fallback.presence || t(".never") if date.blank?

    case format
    when :relative
      helpers.time_ago_in_words(date)
    when :date_only
      I18n.l(date.to_date, format: :default)
    when :time_only
      date.respond_to?(:strftime) ? I18n.l(date, format: "%H:%M") : ""
    else
      I18n.l(date, format: format)
    end
  rescue StandardError
    date.to_s
  end
end
