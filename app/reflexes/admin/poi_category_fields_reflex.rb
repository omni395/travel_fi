# frozen_string_literal: true

#
# Admin::PoiCategoryFieldsReflex - обработчик WebSocket событий для управления полями категорий POI
#
# Отвечает за:
# - Создание/обновление/удаление полей категорий
#
class Admin::PoiCategoryFieldsReflex < ApplicationReflex
  #
  # Создаёт новое поле для категории POI
  #
  # @param params [Hash] параметры поля { poi_category_id:, field_key:, field_type:, label:, ... }
  #
  def create(params = {})
    morph :nothing

    category = PoiCategory.find(params[:poi_category_id] || element.dataset.poiCategoryId)
    authorize_with_pundit!(category, :update?)

    field = PoiCategoryService.create_field(
      category: category,
      params: params,
      current_user: current_user
    )

    component = Admin::PoiCategories::FieldsListComponent.new(category: category)
    html = ApplicationController.render(component, layout: false)
    morph "[data-poi-category-fields]", html

    send_success(I18n.t("reflexes.admin.poi_category_fields.create_success"))
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.poi_category_fields.create_unauthorized"))
  rescue PoiCategoryService::CreateError => e
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("PoiCategoryField create error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.poi_category_fields.create_error"))
  end

  #
  # Обновляет поле категории POI
  #
  # @param params [Hash] параметры поля
  #
  def update(params = {})
    morph :nothing

    field = PoiCategoryField.find(params[:id] || element.dataset.id)
    authorize_with_pundit!(field.poi_category, :update?)

    PoiCategoryService.update_field(
      field: field,
      params: params,
      current_user: current_user
    )

    component = Admin::PoiCategory::FieldsListComponent.new(category: field.poi_category)
    html = ApplicationController.render(component, layout: false)
    morph "[data-poi-category-fields]", html

    send_success(I18n.t("reflexes.admin.poi_category_fields.update_success"))
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.poi_category_fields.update_unauthorized"))
  rescue PoiCategoryService::UpdateError => e
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("PoiCategoryField update error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.poi_category_fields.update_error"))
  end

  #
  # Удаляет поле категории POI
  #
  # @param params [Hash] параметры { id: Integer }
  #
  def destroy(params = {})
    morph :nothing

    field = PoiCategoryField.find(params[:id] || element.dataset.id)
    authorize_with_pundit!(field.poi_category, :update?)

    category = field.poi_category
    PoiCategoryService.destroy_field(
      field: field,
      current_user: current_user
    )

    component = Admin::PoiCategory::FieldsListComponent.new(category: category)
    html = ApplicationController.render(component, layout: false)
    morph "[data-poi-category-fields]", html

    send_success(I18n.t("reflexes.admin.poi_category_fields.destroy_success"))
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.poi_category_fields.destroy_unauthorized"))
  rescue PoiCategoryService::DestroyError => e
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("PoiCategoryField destroy error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.poi_category_fields.destroy_error"))
  end

  #
  # Перемещает поле вверх/вниз по позиции
  #
  # @param params [Hash] { id: Integer, direction: "up" | "down" }
  #
  def reorder(field_id = nil, direction = nil)
    field_id ||= element.dataset.fieldId || element.dataset.id
    field = PoiCategoryField.find(field_id)
    authorize_with_pundit!(field.poi_category, :update?)

    PoiCategoryService.reorder_field(field: field, direction: direction || "up")

    component = Admin::PoiCategories::FieldsListComponent.new(category: field.poi_category)
    html = ApplicationController.render(component, layout: false)
    morph "[data-poi-category-fields]", html
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.poi_category_fields.update_unauthorized"))
  rescue StandardError => e
    Rails.logger.error("PoiCategoryField reorder error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.poi_category_fields.update_error"))
  end

  private

  #
  # Отправляет ошибку в браузер
  #
  # @param message [String] сообщение об ошибке
  #
  def send_error(message)
    return unless current_user

    cable_ready[current_user.to_gid_param].dispatch_event(
      name: "adminPoiCategoryFieldsError",
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
      name: "adminPoiCategoryFieldsSuccess",
      detail: { message: message || I18n.t("reflexes.admin.poi_category_fields.operation_success") }
    )
    cable_ready.broadcast
  end
end
