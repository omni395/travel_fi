# frozen_string_literal: true

#
# Admin::PoisReflex - обработчик WebSocket событий для управления POI
#
# Отвечает за:
# - Изменение статуса POI (модерация)
# - Фильтрацию и поиск POI
# - Сортировку POI
#
class Admin::PoisReflex < ApplicationReflex
  PER_PAGE = 20

  #
  # Обновляет POI
  #
  # @param params [Hash] параметры POI
  #
  def update(params = {})
    morph :nothing

    poi = Poi.find(params[:id] || element.dataset.id)
    authorize_with_pundit!(poi, :update?)

    PoiService.update(
      poi: poi,
      params: params,
      current_user: current_user
    )

    component = Admin::Poi::ShowComponent.new(poi: poi)
    html = ApplicationController.render(component, layout: false)
    morph "#poi-detail", html

    send_success(I18n.t("reflexes.admin.pois.update_success"))
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.pois.update_unauthorized"))
  rescue PoiService::UpdateError => e
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("Poi update error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.pois.update_error"))
  end

  #
  # Изменяет статус POI (модерация)
  #
  # @param params [Hash] параметры { id: Integer, status: String }
  #
  def change_status(params = {})
    morph :nothing

    poi = Poi.find(params[:id] || element.dataset.id)
    authorize_with_pundit!(poi, :moderate?)

    PoiService.change_status(
      poi: poi,
      status: params[:status],
      current_user: current_user
    )

    component = Admin::Poi::ShowComponent.new(poi: poi)
    html = ApplicationController.render(component, layout: false)
    morph "#poi-detail", html

    send_success(I18n.t("reflexes.admin.pois.status_changed", status: params[:status]))
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.pois.moderate_unauthorized"))
  rescue PoiService::StatusError => e
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("Poi status change error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.pois.status_change_error"))
  end

  #
  # Удаляет POI
  #
  # @param params [Hash] параметры { poi_id: Integer }
  #
  def destroy(params = {})
    morph :nothing

    poi_id = params[:poi_id]
    poi = Poi.find(poi_id)
    authorize_with_pundit!(poi, :destroy?)

    PoiService.destroy(
      poi: poi,
      current_user: current_user
    )

    cable_ready.redirect_to(url: admin_pois_path)
    cable_ready.broadcast
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.pois.destroy_unauthorized"))
  rescue PoiService::DestroyError => e
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("Poi destroy error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.pois.destroy_error"))
  end

  #
  # Фильтрует POI
  #
  # @param params [Hash] параметры { query:, status:, category_id:, page: }
  #
  def filter(params = {})
    morph :nothing

    query = params[:query]
    status = params[:status]
    category_id = params[:category_id]
    page = (params[:page] || 1).to_i
    sort_column = params[:sort_column] || session[:admin_pois_sort_column]
    sort_direction = params[:sort_direction] || session[:admin_pois_sort_direction]
    authorize_with_pundit!(Poi, :index?)

    session[:admin_pois_sort_column] = sort_column
    session[:admin_pois_sort_direction] = sort_direction

    pois = PoiService.search_pois(query: query, status: status, category_id: category_id,
                                  sort_column: sort_column, sort_direction: sort_direction)
    @pagy, pois = pagy(pois, limit: PER_PAGE, page: page)

    morph "[data-admin-pois-list]", render_pois_table(pois, @pagy)
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.pois.filter_unauthorized"))
  rescue StandardError => e
    Rails.logger.error("Pois filter error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.pois.filter_error"))
  end

  #
  # Сортирует POI
  #
  # @param params [Hash] параметры { column:, query:, status:, category_id: }
  #
  def sort(params = {})
    morph :nothing

    column = params[:column]
    query = params[:query]
    status = params[:status]
    category_id = params[:category_id]
    authorize_with_pundit!(Poi, :index?)

    current_column = session[:admin_pois_sort_column]
    current_direction = session[:admin_pois_sort_direction]

    if current_column == column
      new_direction = current_direction == 'asc' ? 'desc' : 'asc'
    else
      new_direction = 'asc'
    end

    session[:admin_pois_sort_column] = column
    session[:admin_pois_sort_direction] = new_direction

    pois = PoiService.search_pois(query: query, status: status, category_id: category_id,
                                  sort_column: column, sort_direction: new_direction)
    @pagy, pois = pagy(pois, limit: PER_PAGE, page: 1)

    morph "[data-admin-pois-list]", render_pois_table(pois, @pagy)
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.pois.filter_unauthorized"))
  rescue StandardError => e
    Rails.logger.error("Pois sort error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.pois.filter_error"))
  end

  #
  # Сбрасывает фильтры POI
  #
  def reset_filters
    morph :nothing

    authorize_with_pundit!(Poi, :index?)

    session.delete(:admin_pois_sort_column)
    session.delete(:admin_pois_sort_direction)

    pois = PoiService.search_pois(query: nil, status: nil, category_id: nil)
    @pagy, pois = pagy(pois, limit: PER_PAGE, page: 1)

    morph "[data-admin-pois-list]", render_pois_table(pois, @pagy)
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.pois.reset_filters_unauthorized"))
  rescue StandardError => e
    Rails.logger.error("Pois reset filters error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.pois.reset_filters_error"))
  end

  private

  #
  # Рендерит таблицу POI (для morph)
  #
  # @param pois [ActiveRecord::Relation] POI для рендеринга
  # @param pagy [Pagy, nil] объект пагинации
  # @return [String] HTML компонента таблицы
  #
  def render_pois_table(pois, pagy = nil)
    component = Admin::Poi::TableComponent.new(pois: pois, pagy: pagy)
    ApplicationController.render(component, layout: false)
  end

  #
  # Отправляет ошибку в браузер
  #
  # @param message [String] сообщение об ошибке
  #
  def send_error(message)
    return unless current_user

    cable_ready[current_user.to_gid_param].dispatch_event(
      name: "adminPoisError",
      detail: { message: message }
    )
    cable_ready.broadcast
  end

  #
  # Отправляет success событие в браузер
  #
  # @param message [String] опциональное сообщение об успехе
  #
  def send_success(message = nil)
    return unless current_user

    cable_ready[current_user.to_gid_param].dispatch_event(
      name: "adminPoisSuccess",
      detail: { message: message || I18n.t("reflexes.admin.pois.operation_success") }
    )
    cable_ready.broadcast
  end
end
