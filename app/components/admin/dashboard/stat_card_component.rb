# frozen_string_literal: true

#
# Admin::Dashboard::StatCardComponent - универсальная компактная карточка статистики
#
class Admin::Dashboard::StatCardComponent < ApplicationComponent
  def initialize(title:, count:, icon:, color: "blue")
    @title = title
    @count = count
    @icon = icon
    @color = color
  end

  private

  #
  # Возвращает Tailwind класс цвета для статистики
  #
  # @return [String] класс цвета (text-primary, text-secondary, text-warning, text-info, text-gray-600)
  #
  def color_class
    case @color
    when "primary" then "text-primary"
    when "secondary" then "text-secondary"
    when "warning" then "text-warning"
    when "info" then "text-info"
    when "success" then "text-success"
    when "error" then "text-error"
    else "text-gray-600"
    end
  end
end
