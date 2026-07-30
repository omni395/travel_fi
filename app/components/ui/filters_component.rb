# frozen_string_literal: true

#
# Ui::FiltersComponent - компонент фильтров и поиска
#
# Отображает строку поиска, опциональный селект статуса и кнопку сброса
#
# @example (пользователи)
#   <%= render Ui::FiltersComponent.new(
#         search_query: @search_query,
#         status_filter: @status_filter,
#         statuses: %w[registered pending_verification active suspended banned deleted],
#         status_model: :user,
#         search_controller: "admin--users--table-component",
#         search_action: "input->admin--users--table-component#filter",
#         filter_action: "change->admin--users--table-component#filter",
#         reset_action: "admin--users--table-component#resetFilters"
#       ) %>
#
# @example (категории - без статусов)
#   <%= render Ui::FiltersComponent.new(
#         search_query: @search_query,
#         statuses: [],  # статус-фильтр не показывается
#         search_controller: "admin--poi-categories--table-component",
#         search_action: "input->admin--poi-categories--table-component#filter",
#         reset_action: "admin--poi-categories--table-component#resetFilters"
#       ) %>
#
class Ui::FiltersComponent < ApplicationComponent
  # @param search_query [String] текущий поисковый запрос
  # @param status_filter [String] текущий фильтр по статусу
  # @param statuses [Array<String>] список доступных статусов (пустой массив = не показывать)
  # @param status_model [Symbol] модель для перевода статусов (:user, :poi)
  # @param search_controller [String] Stimulus контроллер для поиска
  # @param search_action [String] Stimulus action для поиска
  # @param filter_action [String] Stimulus action для фильтра
  # @param reset_action [String] Stimulus action для сброса
  def initialize(
    search_query: nil,
    status_filter: nil,
    statuses: %w[registered pending_verification active suspended banned deleted],
    status_model: :user,
    search_controller: "admin--users--table-component",
    search_action: "input->admin--users--table-component#filter",
    filter_action: "change->admin--users--table-component#filter",
    reset_action: "admin--users--table-component#resetFilters"
  )
    @search_query = search_query
    @status_filter = status_filter
    @statuses = statuses
    @status_model = status_model
    @search_controller = search_controller
    @search_action = search_action
    @filter_action = filter_action
    @reset_action = reset_action
  end

  private

  attr_reader :search_query, :status_filter, :statuses, :status_model,
              :search_controller, :search_action,
              :filter_action, :reset_action

  #
  # Возвращает ключ для перевода статуса
  #
  # @param status [String] ключ статуса
  # @return [String] переведённое название статуса
  #
  def status_label(status)
    case status_model
    when :poi
      I18n.t("activerecord.attributes.poi.statuses.#{status}", default: status.humanize)
    when :poi_category
      I18n.t("activerecord.attributes.poi_category.statuses.#{status}", default: status.humanize)
    else
      I18n.t("activerecord.attributes.user.statuses.#{status}", default: status.humanize)
    end
  end

  #
  # Показывать ли статус-фильтр
  #
  # @return [Boolean]
  #
  def show_status_filter?
    statuses.any?
  end
end
