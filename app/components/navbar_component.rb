# frozen_string_literal: true

#
# NavbarComponent - фиксированная навигационная панель приложения
#
# Отвечает за отображение шапки приложения с поддержкой:
# - Многоязычности (EN, RU, ES, ZH) с определением локали из браузера
# - Многоролевости (admin, moderator, user)
# - Мобильной и десктопной адаптивности
# - Цветовой схемы: зелено-голубые тона (teal-sky)
#
class NavbarComponent < ApplicationComponent
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
  # Если аватарка есть в storage - возвращает её URL
  # Иначе возвращает путь к изображению по умолчанию
  #
  # @return [String] URL аватарки или путь к no-image.png
  #
  def user_avatar
    @user.avatar_url.present? ? @user.avatar_url : "no-image.png"
  end

  #
  # Возвращает пункты главного меню приложения
  # Используется для навигации между основными разделами
  #
  # @return [Array<Hash>] массив пунктов меню с label и path
  #
  def main_menu_items
    [
      { label: t("navbar.home"), path: root_path(locale: I18n.locale) }
    ]
  end

  #
  # Возвращает доступные языки для выбора
  # Поддерживает 4 локали: EN, RU, ES, ZH
  # Локали передаются в URL как [:locale]/page
  #
  # @return [Array<Hash>] массив языков с label и path
  #
  def language_items
    items = []
    # Получаем текущий путь без локали
    current_path = request.path.sub(/^\/(en|ru|es|zh)(-[A-Z]{2})?/, "")

    items << { label: t("navbar.languages.en"), path: "/en#{current_path}" }
    items << { label: t("navbar.languages.ru"), path: "/ru#{current_path}" }
    items << { label: t("navbar.languages.es"), path: "/es#{current_path}" }
    items << { label: t("navbar.languages.zh"), path: "/zh#{current_path}" }
    items
  end

  #
  # Возвращает пункты меню пользователя (профиль, выход и т.д.)
  # Первоначально проверяет наличие авторизованного пользователя
  #
  # @return [Array<Hash>] массив пунктов меню с label и path
  #
  def user_menu_items
    return [] unless user_signed_in?

    items = []

    # Админ-панель доступна только админам и модераторам
    if @user.admin? || @user.moderator?
      items << {
        label: t("navbar.admin_panel"),
        path: "/#{I18n.locale}/admin",
        method: :get
      }
    end

    # Основные пункты меню для авторизованного пользователя
    items << { label: t("navbar.profile"), path: "#", method: :get }
    items << { label: t("navbar.settings"), path: "#", method: :get }
    items << { label: t("navbar.logout"), path: destroy_user_session_path, method: :delete }

    items
  end
end