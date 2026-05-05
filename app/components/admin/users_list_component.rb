# frozen_string_literal: true

#
# Admin::UsersListComponent - компонент списка пользователей
#
# Отображает:
# - Таблицу пользователей с пагинацией
# - Фильтры и поиск
# - Детальный вид пользователя
# - Форму редактирования пользователя
#
# @param users [ActiveRecord::Relation] пользователи с пагинацией
# @param search_query [String] поисковый запрос
# @param status_filter [String] фильтр по статусу
# @param selected_user [User, nil] выбранный пользователь для детального вида
# @param edit_mode [Boolean] режим редактирования
# @param roles [Array<Role>] список доступных ролей
#
class Admin::UsersListComponent < ApplicationComponent
  def initialize(users:, search_query: nil, status_filter: nil, selected_user: nil, edit_mode: false, roles: [])
    @users = users
    @search_query = search_query
    @status_filter = status_filter
    @selected_user = selected_user
    @edit_mode = edit_mode
    @roles = roles
  end

  #
  # Возвращает CSS класс для статуса пользователя
  #
  # @param status [String] статус пользователя
  # @return [String] CSS класс
  #
  def status_badge_class(status)
    case status.to_s
    when 'active'
      'badge-success'
    when 'pending_verification'
      'badge-warning'
    when 'suspended'
      'badge-warning'
    when 'banned'
      'badge-error'
    when 'deleted'
      'badge-neutral'
    else
      'badge-neutral'
    end
  end

  #
  # Проверяет, есть ли активные фильтры
  #
  # @return [Boolean] true если есть фильтры
  #
  def has_filters?
    @search_query.present? || @status_filter.present?
  end

  #
  # Проверяет, выбран ли пользователь
  #
  # @return [Boolean] true если выбран пользователь
  #
  def user_selected?
    @selected_user.present?
  end

  #
  # Проверяет, режим редактирования
  #
  # @return [Boolean] true если режим редактирования
  #
  def edit_mode?
    @edit_mode
  end
end

