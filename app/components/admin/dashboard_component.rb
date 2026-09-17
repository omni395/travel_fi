# frozen_string_literal: true

#
# Admin::DashboardComponent - компонент дашборда админки
#
# Отображает:
# - Статистику по пользователям
# - Список последних пользователей
# - Последние активности
#
# @param stats [Hash] статистика админки
# @param recent_users [Array<User>] последние пользователи
# @param recent_activities [Array<PaperTrail::Version>] последние активности
#
class Admin::DashboardComponent < ApplicationComponent
  def initialize(stats:, recent_users:, recent_activities:)
    @stats = stats
    @recent_users = recent_users
    @recent_activities = recent_activities
  end

  #
  # Возвращает CSS класс для карточки статистики
  #
  # @param type [Symbol] тип статистики
  # @return [String] CSS класс
  #
  def stat_card_class(type)
    case type
    when :total_users
      'border-teal-500'
    when :active_users
      'border-green-500'
    when :suspended_users
      'border-red-500'
    when :new_users_today
      'border-blue-500'
    end
  end

  #
  # Возвращает CSS класс для иконки карточки статистики
  #
  # @param type [Symbol] тип статистики
  # @return [String] CSS класс
  #
  def stat_icon_class(type)
    case type
    when :total_users
      'bg-teal-100 text-teal-600'
    when :active_users
      'bg-green-100 text-green-600'
    when :suspended_users
      'bg-red-100 text-red-600'
    when :new_users_today
      'bg-blue-100 text-blue-600'
    end
  end

  #
  # Возвращает имя иконки MDI для карточки статистики
  #
  # @param type [Symbol] тип статистики
  # @return [String] имя иконки
  #
  def stat_icon_name(type)
    case type
    when :total_users
      'mdi-account-multiple'
    when :active_users
      'mdi-account-check'
    when :suspended_users
      'mdi-account-off'
    when :new_users_today
      'mdi-account-plus'
    end
  end

  #
  # Возвращает локализованный текст для типа статистики
  #
  # @param type [Symbol] тип статистики
  # @return [String] локализованный текст
  #
  def stat_label(type)
    case type
    when :total_users
      t('admin.dashboard.total_users')
    when :active_users
      t('admin.dashboard.active_users')
    when :suspended_users
      t('admin.dashboard.suspended_users')
    when :new_users_today
      t('admin.dashboard.new_users_today')
    end
  end

  #
  # Возвращает CSS класс для статуса пользователя
  # Используется для цветового обозначения статуса в таблицах
  #
  # @param status [String] статус пользователя
  # @return [String] CSS класс для статуса
  #
  def user_status_class(status)
    case status.to_s
    when 'active'
      'bg-green-100 text-green-800'
    when 'pending_verification'
      'bg-yellow-100 text-yellow-800'
    when 'suspended'
      'bg-orange-100 text-orange-800'
    when 'banned'
      'bg-red-100 text-red-800'
    when 'deleted'
      'bg-gray-100 text-gray-800'
    else
      'bg-gray-100 text-gray-800'
    end
  end

  #
  # Возвращает название цвета для StatCardComponent
  #
  # @param type [Symbol] тип статистики
  # @return [String] название цвета (primary, secondary, warning, info)
  #
  def stat_color(type)
    case type
    when :total_users then 'primary'
    when :active_users then 'success'
    when :suspended_users then 'error'
    when :new_users_today then 'info'
    else 'gray'
    end
  end
end
