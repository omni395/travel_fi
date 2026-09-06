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

    # Без redirect: форма сохраняется через Reflex, обновление DOM выполняет
    # Broadcaster (PaperTrail → VersionObserverJob → PoiCategoryBroadcaster).
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
  # Удаляет категорию POI. После успешного удаления редиректит на список категорий.
  #
  # @param params [Hash] параметры { id: Integer }
  #
  def destroy(params = {})
    morph :nothing

    normalized = deep_symbolize_keys(params)
    category = PoiCategory.friendly.find(normalized[:id] || element.dataset.id)
    authorize_with_pundit!(category, :destroy?)

    PoiCategoryService.destroy(category: category, current_user: current_user)

    cable_ready.redirect_to(url: admin_poi_categories_path)
    cable_ready.broadcast

    send_success(I18n.t("reflexes.admin.poi_categories.destroy_success"))
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.poi_categories.destroy_unauthorized"))
  rescue PoiCategoryService::DestroyError => e
    send_error(e.message)
  rescue StandardError => e
    Rails.logger.error("PoiCategory destroy error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.poi_categories.destroy_error"))
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
  # Запускает импорт POI из OpenStreetMap для категории
  #
  # Выполняется синхронно в Reflex (через открытый WebSocket), т.к. CableReady
  # из SolidQueue worker'a не гарантирует доставку через SolidCable (см. ROADMAP.md
  # — "Известные архитектурные долги").
  #
  # Прогресс отправляется через OsmImportBroadcaster напрямую в UserChannel.
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

    loc = location.symbolize_keys.slice(:city, :country, :bbox)

    # Делегируем в Service (OsmImportService#import): fetch + первичный прогресс + обработка.
    # В колбэке — только UI: прогресс-бродкаст + инкрементальный апдейт вкладки POIs.
    stats = OsmImportService.import(
      category: category,
      location: loc,
      user: current_user
    ) do |processed, total, already_in_db|
      OsmImportBroadcaster.progress(
        user: current_user,
        total: total,
        processed: processed,
        already_in_db: already_in_db
      )

      # Инкрементальный апдейт вкладки POIs: каждые 10 обработанных новых POI
      # появляются в списке ПО МЕРЕ добавления (не только по завершении импорта).
      broadcast_pois_panel(category) if processed.positive? && (processed % 10).zero?
    end

    # Отправляем результат + обновляем UI категории + триггерим перезагрузку карты.
    # bbox передаётся для гео-фильтрации reload карты (баг 4).
    OsmImportBroadcaster.call(user: current_user, stats: stats, category: category, bbox: loc[:bbox])

    Rails.logger.info "[OsmImport] complete for category##{category.id} (#{category.slug}): " \
                      "#{stats[:created]} created, #{stats[:skipped_duplicate]} duplicate, " \
                      "#{stats[:skipped_modified]} modified, #{stats[:errors]} errors"
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.poi_categories.import_unauthorized"))
  rescue StandardError => e
    Rails.logger.error("PoiCategory import_from_osm error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.poi_categories.import_error"))
  end

  #
  # Пагинация списка POI категории (вкладка POIs)
  # Не меняет БД — только рендерит панель для выбранной страницы
  #
  # @param params [Hash] { category_id:, pois_page: }
  #
  def pois_page(params = {})
    morph :nothing
    normalized = deep_symbolize_keys(params)

    category = PoiCategory.friendly.find(normalized[:category_id] || element.dataset.poiCategoryId)
    authorize_with_pundit!(category, :show?)

    pagy, pois = pagy(
      category.pois.includes(:user).order(created_at: :desc),
      limit: 10,
      page: (normalized[:pois_page] || 1).to_i
    )
    html = ApplicationController.render(
      Admin::PoiCategories::PoiCategory::PoisListComponent.new(category: category, pagy: pagy, pois: pois),
      layout: false
    )

    cable_ready["admin_feed"].inner_html(selector: "[data-poi-category-pois]", html: html)
    cable_ready["admin_feed"].broadcast
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.poi_categories.filter_unauthorized"))
  rescue StandardError => e
    Rails.logger.error("PoiCategory pois_page error: #{e.class} #{e.message}")
    send_error(I18n.t("reflexes.admin.poi_categories.filter_error"))
  end

  #
  # Пагинация ленты аудита категории (вкладка Audit Log)
  # Не меняет БД — только рендерит панель для выбранной страницы
  #
  # @param params [Hash] { category_id:, audit_page: }
  #
  def audit_page(params = {})
    morph :nothing
    normalized = deep_symbolize_keys(params)

    category = PoiCategory.friendly.find(normalized[:category_id] || element.dataset.poiCategoryId)
    authorize_with_pundit!(category, :show?)

    versions = PoiCategoryService.audit_versions(category: category).order(created_at: :desc)
    pagy, versions = pagy(versions, limit: 10, page: (normalized[:audit_page] || 1).to_i)

    # Единый рендер с Broadcaster — панель аудита через AuditLogComponent
    html = ApplicationController.render(
      Admin::PoiCategories::PoiCategory::AuditLogComponent.new(category: category, versions: versions, pagy: pagy),
      layout: false
    )

    cable_ready["admin_feed"].inner_html(selector: "[data-audit-log]", html: html)
    cable_ready["admin_feed"].broadcast
  rescue Pundit::NotAuthorizedError => e
    send_error(I18n.t("reflexes.admin.poi_categories.filter_unauthorized"))
  rescue StandardError => e
    Rails.logger.error("PoiCategory audit_page error: #{e.class} #{e.message}")
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
    component = Admin::PoiCategories::TableComponent.new(categories: categories, pagy: pagy)
    ApplicationController.render(component, layout: false)
  end

  #
  # Инкрементально обновляет вкладку POIs (первая страница) через AdminChannel.
  # Вызывается из блока прогресса импорта — новые POI появляются по мере добавления.
  # Рендер изолирован в rescue: сбой одной итерации не роняет импорт.
  #
  # @param category [PoiCategory] категория, список POI которой обновляем
  #
  def broadcast_pois_panel(category)
    pagy, pois = pagy(
      category.pois.includes(:user).order(created_at: :desc),
      limit: 10,
      page: 1
    )
    html = ApplicationController.render(
      Admin::PoiCategories::PoiCategory::PoisListComponent.new(category: category, pagy: pagy, pois: pois),
      layout: false
    )

    cable_ready["admin_feed"].inner_html(selector: "[data-poi-category-pois]", html: html)
    cable_ready["admin_feed"].broadcast
  rescue StandardError => e
    Rails.logger.error("PoiCategory pois panel incremental update failed: #{e.class} #{e.message}")
  end

  #
  # Отправляет ошибку в браузер
  #
  # @param message [String] сообщение об ошибке
  #
  def send_error(message)
    return unless current_user

    cable_ready["admin_#{current_user.id}"].dispatch_event(
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

    cable_ready["admin_#{current_user.id}"].dispatch_event(
      name: "adminPoiCategoriesSuccess",
      detail: { message: message || I18n.t("reflexes.admin.poi_categories.operation_success") }
    )
    cable_ready.broadcast
  end
end
