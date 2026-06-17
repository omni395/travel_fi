# frozen_string_literal: true

#
# Ui::FiltersComponent - компонент фильтров и поиска
#
# Отображает строку поиска, селект статуса и кнопку сброса
#
# @example
#   <%= render Ui::FiltersComponent.new(
#         search_query: @search_query,
#         status_filter: @status_filter,
#         statuses: %w[active suspended banned pending_verification],
#         search_controller: "admin--users",
#         search_action: "input->admin--users#search",
#         filter_action: "change->admin--users#filterByStatus",
#         reset_action: "admin--users#resetFilters"
#       ) %>
#
class Ui::FiltersComponent < ApplicationComponent
  # @param search_query [String] текущий поисковый запрос
  # @param status_filter [String] текущий фильтр по статусу
  # @param statuses [Array<String>] список доступных статусов
  # @param search_controller [String] Stimulus контроллер для поиска
  # @param search_action [String] Stimulus action для поиска
  # @param filter_action [String] Stimulus action для фильтра
  # @param reset_action [String] Stimulus action для сброса
  def initialize(
    search_query: nil,
    status_filter: nil,
    statuses: %w[registered pending_verification active suspended banned deleted],
    search_controller: "admin--users",
    search_action: "input->admin--users#search",
    filter_action: "change->admin--users#filterByStatus",
    reset_action: "admin--users#resetFilters"
  )
    @search_query = search_query
    @status_filter = status_filter
    @statuses = statuses
    @search_controller = search_controller
    @search_action = search_action
    @filter_action = filter_action
    @reset_action = reset_action
  end

  private

  attr_reader :search_query, :status_filter, :statuses,
              :search_controller, :search_action,
              :filter_action, :reset_action
end
