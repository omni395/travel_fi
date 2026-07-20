# frozen_string_literal: true

#
# Admin::PoiCategoriesReflex - обработчик WebSocket событий для управления категориями POI
#
# Отвечает за:
# - Создание/обновление категорий
# - Фильтрацию и поиск категорий
#
class Admin::PoiCategoriesReflex < ApplicationReflex
  PER_PAGE = 20

  #
  # Создаёт новую категорию POI
  #
  # @param params [Hash] параметры категории
  #
  def create(params = {})
    morph :nothing

    authorize_with_pundit!(PoiCategory, :create?)

    category = PoiCategoryService.create(
      params: params,
      current_user: current_user
    )

    cable_ready.redirect_to(url: admin_poi_category_path(id: category))
    cable_ready.broadcast

    send_success(I18n.t("reflexes.admin.poi_categories.create_success"))
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.poi_categories.create_unauthorized"))
  rescue PoiCategoryService::CreateError => e
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("PoiCategory create error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.poi_categories.create_error"))
  end

  #
  # Обновляет категорию POI
  #
  # @param params [Hash] параметры категории
  #
  def update(params = {})
    morph :nothing

    category = PoiCategory.friendly.find(params[:id] || element.dataset.id)
    authorize_with_pundit!(category, :update?)

    PoiCategoryService.update(
      category: category,
      params: params,
      current_user: current_user
    )

    component = Admin::PoiCategories::PoiCategory::ShowComponent.new(category: category)
    html = ApplicationController.render(component, layout: false)
    morph "#poi-category-detail", html

    send_success(I18n.t("reflexes.admin.poi_categories.update_success"))
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.poi_categories.update_unauthorized"))
  rescue PoiCategoryService::UpdateError => e
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("PoiCategory update error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.poi_categories.update_error"))
  end

  #
  # Фильтрует категории
  #
  # @param params [Hash] параметры { query:, active:, page: }
  #
  def filter(params = {})
    query = params[:query]
    active = params[:active]
    page = (params[:page] || 1).to_i
    authorize_with_pundit!(PoiCategory, :index?)

    categories = PoiCategoryService.search_categories(query: query, active: active)
    @pagy, categories = pagy(categories, limit: PER_PAGE, page: page)

    morph "[data-admin-poi-categories-list]", render_categories_table(categories, @pagy)
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.poi_categories.filter_unauthorized"))
  rescue StandardError => e
    Rails.logger.error("PoiCategories filter error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.poi_categories.filter_error"))
  end

  private

  #
  # Рендерит таблицу категорий (для morph)
  #
  # @param categories [ActiveRecord::Relation] категории
  # @param pagy [Pagy, nil] объект пагинации
  # @return [String] HTML компонента таблицы
  #
  def render_categories_table(categories, pagy = nil)
    component = Admin::PoiCategory::TableComponent.new(categories: categories, pagy: pagy)
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
      name: "adminPoiCategoriesError",
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
      name: "adminPoiCategoriesSuccess",
      detail: { message: message || I18n.t("reflexes.admin.poi_categories.operation_success") }
    )
    cable_ready.broadcast
  end
end
