# frozen_string_literal: true

#
# Ui::FiltersComponent - компонент фильтров и поиска
#
# Отображает строку поиска, опциональный селект статуса, дополнительные кастомные фильтры и кнопку сброса
#
# @example (базовый с поиском и статусами)
#   <%= render Ui::FiltersComponent.new(
#         search_query: @search_query,
#         status_filter: @status_filter,
#         statuses: %w[pending active inactive suspended banned deleted],
#         status_model: :user,
#         search_action: "input->admin--users--table-component#filter",
#         filter_action: "admin--users--table-component#filter",
#         reset_action: "admin--users--table-component#resetFilters"
#       ) %>
#
# @example (расширенный со слотами кастомных фильтров)
#   <%= render Ui::FiltersComponent.new(reset_action: "admin--orders--table-component#resetFilters") do |f| %>
#     <% f.with_search do %>
#       <input type="text" placeholder="Поиск по ID..." class="field-input text-sm">
#     <% end %>
#     <% f.with_filter do %>
#       <input type="date" class="field-input text-sm">
#     <% end %>
#   <% end %>
#
class Ui::FiltersComponent < ApplicationComponent
  renders_one :search
  renders_many :filters
  renders_one :extra_actions

  # @param search_query [String, nil] текущий поисковый запрос
  # @param search_placeholder [String, nil] плейсхолдер для поля поиска
  # @param status_filter [String, nil] текущий фильтр по статусу
  # @param statuses [Array<String, Symbol>] список доступных статусов (пустой массив = не показывать)
  # @param status_model [Symbol, nil] модель для перевода статусов (:user, :poi)
  # @param search_action [String, nil] Stimulus action для поиска
  # @param filter_action [String, nil] Stimulus action для фильтра
  # @param reset_action [String, nil] Stimulus action для сброса
  def initialize(
    search_query: nil,
    search_placeholder: nil,
    status_filter: nil,
    statuses: [],
    status_model: nil,
    search_action: nil,
    filter_action: nil,
    reset_action: nil
  )
    @search_query = search_query
    @search_placeholder = search_placeholder
    @status_filter = status_filter
    @statuses = statuses || []
    @status_model = status_model
    @search_action = search_action
    @filter_action = filter_action
    @reset_action = reset_action
  end

  private

  attr_reader :search_query, :search_placeholder, :status_filter, :statuses,
              :status_model, :search_action, :filter_action, :reset_action

  #
  # Возвращает ключ для перевода статуса
  #
  # @param status [String, Symbol] ключ статуса
  # @return [String] переведённое название статуса
  #
  def status_label(status)
    return status.to_s.humanize unless status_model

    case status_model.to_sym
    when :poi
      I18n.t("activerecord.attributes.poi.statuses.#{status}", default: status.to_s.humanize)
    when :poi_category
      I18n.t("activerecord.attributes.poi_category.statuses.#{status}", default: status.to_s.humanize)
    else
      I18n.t("activerecord.attributes.#{status_model}.statuses.#{status}", default: status.to_s.humanize)
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
