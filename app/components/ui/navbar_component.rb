# frozen_string_literal: true

#
# Ui::NavbarComponent - фиксированная навигационная панель приложения
#
# Отвечает за отображение шапки приложения с поддержкой:
# - Многоязычности (EN, RU, ES, ZH) с определением локали из браузера
# - Многоролевости (admin, moderator, user)
# - Мобильной и десктопной адаптивности
# - Цветовой схемы: зелено-голубая гамма (teal-sky)
#
class Ui::NavbarComponent < ApplicationComponent
  #
  # Инициализирует компонент с текущим пользователем
  #
  # @param user [User, nil] текущий авторизованный пользователь
  #
  def initialize(user: nil)
    @user = user
  end

  #
  # Проверяет, авторизован ли пользователь
  #
  # @return [Boolean] true если пользователь авторизован
  #
  def user_signed_in?
    @user.present?
  end

  #
  # Возвращает URL аватарки пользователя
  #
  # @return [String] URL аватарки или путь к no-image.png
  #
  def user_avatar_url
    if @user.avatar.attached?
      url_for(@user.avatar)
    else
      "no-image.png"
    end
  end

  #
  # Пункты главного меню
  #
  # @return [Array<Hash>]
  #
  def main_menu_items
    [
      { label: t(".home"), path: root_path(locale: I18n.locale), icon: "mdi-home" },
      { label: t(".map"), path: pois_path(locale: I18n.locale), icon: "mdi-map-marker-multiple" }
    ]
  end

  #
  # Доступные языки для выбора
  #
  # @return [Array<Hash>]
  #
  #
  # Список доступных языков для переключения
  #
  # Использует helpers.url_for для сохранения текущего роута —
  # Rails автоматически подменяет только параметр locale в пути.
  #
  # @return [Array<Hash>] массив с label и path для каждого языка
  #
  def language_items
    I18n.available_locales.map do |locale|
      { label: t(".languages_full.#{locale}"), path: helpers.url_for(locale: locale, only_path: true) }
    end
  end

  #
  # Пункты меню пользователя
  #
  # @return [Array<Hash>]
  #
  def user_menu_items
    return [] unless user_signed_in?
    items = []
    if helpers.policy(@user).admin_panel_access?
      items << { label: t(".admin_panel"), path: "/#{I18n.locale}/admin-panel", method: :get }
    end
    items << { label: t(".profile"), path: "#", method: :get }
    items << { label: t(".settings"), path: "#", method: :get }
    items << { label: t(".logout"), path: destroy_user_session_path, method: :delete }
    items
  end
end
