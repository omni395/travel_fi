# frozen_string_literal: true

#
# AdminHelper - хелпер для админ-панели
#
# Содержит вспомогательные методы для отображения данных в админке
#
module AdminHelper
  #
  # Возвращает CSS класс для статуса пользователя
  # Используется для цветового обозначения статуса в таблицах
  #
  # @param status [String] статус пользователя
  # @return [String] CSS класс для статуса
  #
  def user_status_class(status)
    case status.to_s
    when "active"
      "bg-green-100 text-green-800"
    when "pending_verification"
      "bg-yellow-100 text-yellow-800"
    when "suspended"
      "bg-orange-100 text-orange-800"
    when "banned"
      "bg-red-100 text-red-800"
    when "deleted"
      "bg-gray-100 text-gray-800"
    else
      "bg-gray-100 text-gray-800"
    end
  end

  #
  # Возвращает опции для выбора статуса пользователя
  # Используется в формах редактирования пользователя
  #
  # @return [Array<Array>] массив пар [название, значение]
  #
  def user_status_options
    [
      [t("activerecord.attributes.user.statuses.pending_verification"), "pending_verification"],
      [t("activerecord.attributes.user.statuses.active"), "active"],
      [t("activerecord.attributes.user.statuses.suspended"), "suspended"],
      [t("activerecord.attributes.user.statuses.banned"), "banned"]
    ]
  end

  #
  # Возвращает CSS класс для flash сообщения
  #
  # @param type [String] тип сообщения
  # @return [String] CSS класс
  #
  def flash_class(type)
    case type.to_sym
    when :notice, :success
      "bg-green-50 border border-green-200"
    when :alert, :error
      "bg-red-50 border border-red-200"
    when :warning
      "bg-yellow-50 border border-yellow-200"
    else
      "bg-blue-50 border border-blue-200"
    end
  end

  #
  # Возвращает иконку для flash сообщения
  #
  # @param type [String] тип сообщения
  # @return [String] имя иконки MDI
  #
  def flash_icon(type)
    case type.to_sym
    when :notice, :success
      "mdi-check-circle text-green-500"
    when :alert, :error
      "mdi-alert-circle text-red-500"
    when :warning
      "mdi-alert text-yellow-500"
    else
      "mdi-information text-blue-500"
    end
  end

  #
  # Возвращает CSS класс для текста flash сообщения
  #
  # @param type [String] тип сообщения
  # @return [String] CSS класс
  #
  def flash_text_class(type)
    case type.to_sym
    when :notice, :success
      "text-green-800"
    when :alert, :error
      "text-red-800"
    when :warning
      "text-yellow-800"
    else
      "text-blue-800"
    end
  end
end
