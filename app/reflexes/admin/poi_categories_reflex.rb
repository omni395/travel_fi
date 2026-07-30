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

    normalized = deep_symbolize_keys(params)

    category = PoiCategoryService.create(
      params: normalized,
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

    # Параметры приходят из JS как вложенный хэш со строковыми ключами.
    # Преобразуем в deep symbolized keys для совместимости с сервисом.
    normalized = deep_symbolize_keys(params)
    id = normalized.delete(:id) || element.dataset.id

    Rails.logger.info "Admin::PoiCategoriesReflex#update normalized: #{normalized.inspect}"

    category = PoiCategory.friendly.find(id)
    authorize_with_pundit!(category, :update?)

    PoiCategoryService.update(
      category: category,
      params: normalized,
      current_user: current_user
    )

    cable_ready.redirect_to(url: admin_poi_category_path(id: category))
    cable_ready.broadcast

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

  #
  # Запускает фоновый импорт POI из OpenStreetMap для категории
  #
  # @param params [Hash] { category_id:, location: { city:, country:, bbox: } }
  #
  def import_from_osm(params = {})
    morph :nothing

    category = PoiCategory.friendly.find(params[:category_id])
    authorize_with_pundit!(category, :update?)

    location = params[:location]
    unless location.is_a?(Hash) && location[:city].present? && location[:bbox].is_a?(Array)
      send_error(I18n.t("reflexes.admin.poi_categories.import_invalid_location"))
      return
    end

    location = location.symbolize_keys
    loc = { city: location[:city], country: location[:country], bbox: location[:bbox] }

    # Получаем элементы из Overpass
    elements = OsmImportService.fetch_elements(category: category, location: loc, user: current_user)
    total = elements.size

    # Отправляем прогресс: найдено N элементов
    OsmImportBroadcaster.progress(user: current_user, total: total, processed: 0)

    # Обрабатываем элементы с прогрессом
    stats = OsmImportService.process_elements(
      elements: elements,
      category: category,
      location: loc,
      user: current_user
    ) do |processed|
      OsmImportBroadcaster.progress(user: current_user, total: total, processed: processed)
    end

    # Отправляем результат через Broadcaster
    OsmImportBroadcaster.call(user: current_user, stats: stats, category: category)

    # Дублируем ивент через Reflex'овый cable_ready — гарантированная доставка с ответом StimulusReflex
    cable_ready["AdminChannel"].dispatch_event(
      name: "osmImportComplete",
      detail: {
        category_id: category.id,
        category_name: category.localized_name,
        created: stats[:created],
        skipped_duplicate: stats[:skipped_duplicate],
        skipped_modified: stats[:skipped_modified],
        errors: stats[:errors]
      }
    )
    cable_ready.broadcast

    Rails.logger.info "[OsmImport] complete for category##{category.id} (#{category.slug}): " \
                      "#{stats[:created]} created, #{stats[:skipped_duplicate]} duplicate, " \
                      "#{stats[:skipped_modified]} modified, #{stats[:errors]} errors"
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.poi_categories.import_unauthorized"))
  rescue StandardError => e
    Rails.logger.error("PoiCategory import_from_osm error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.poi_categories.import_error"))
  end

  private

  #
  # Рекурсивно преобразует строковые ключи хэша в символьные.
  # Необходимо для совместимости params из JS (строковые ключи)
  # с сервисным слоем, где используются символьные ключи (slice, dig).
  #
  # @param obj [Hash, Array, Object] данные для нормализации
  # @return [Hash, Array, Object] нормализованные данные
  #
  def deep_symbolize_keys(obj)
    case obj
    when Hash
      obj.each_with_object({}) { |(k, v), h| h[k.to_sym] = deep_symbolize_keys(v) }
    when Array
      obj.map { |v| deep_symbolize_keys(v) }
    else
      obj
    end
  end

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
