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
    # Отменяем полный перерендер: обновление DOM выполняет Broadcaster
    # (Database-Triggered Architecture из README)
    morph :nothing

    # Параметры приходят из JS со строковыми ключами — нормализуем в символьные
    normalized = deep_symbolize_keys(params)

    category = PoiCategory.find(normalized[:poi_category_id] || element.dataset.poiCategoryId)
    authorize_with_pundit!(category, :update?)

    PoiCategoryService.create_field(
      category: category,
      params: normalized,
      current_user: current_user
    )

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
    # Отменяем полный перерендер: обновление DOM выполняет Broadcaster
    morph :nothing

    # Параметры приходят из JS со строковыми ключами — нормализуем в символьные
    normalized = deep_symbolize_keys(params)

    field = PoiCategoryField.find(normalized[:field_id] || element.dataset.fieldId)
    authorize_with_pundit!(field.poi_category, :update?)

    PoiCategoryService.update_field(
      field: field,
      params: normalized,
      current_user: current_user
    )

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
    # Отменяем полный перерендер: обновление DOM выполняет Broadcaster
    morph :nothing

    # Параметры приходят из JS со строковыми ключами — нормализуем в символьные
    normalized = deep_symbolize_keys(params)

    field = PoiCategoryField.find(normalized[:field_id] || element.dataset.fieldId)
    authorize_with_pundit!(field.poi_category, :update?)

    PoiCategoryService.destroy_field(
      field: field,
      current_user: current_user
    )

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
    # Отменяем полный перерендер: обновление DOM выполняет Broadcaster
    morph :nothing

    field_id ||= element.dataset.fieldId || element.dataset.id
    field = PoiCategoryField.find(field_id)
    authorize_with_pundit!(field.poi_category, :update?)

    PoiCategoryService.reorder_field(field: field, direction: direction || "up")
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

    cable_ready["admin_#{current_user.id}"].dispatch_event(
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

    cable_ready["admin_#{current_user.id}"].dispatch_event(
      name: "adminPoiCategoryFieldsSuccess",
      detail: { message: message || I18n.t("reflexes.admin.poi_category_fields.operation_success") }
    )
    cable_ready.broadcast
  end
end
