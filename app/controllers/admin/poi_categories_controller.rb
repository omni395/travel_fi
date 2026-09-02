# frozen_string_literal: true

#
# Admin::PoiCategoriesController - контроллер для управления категориями POI в админке
#
# Отвечает за:
# - Список категорий с фильтрацией (index)
# - Детальную страницу категории с полями (show)
# - Создание/обновление категорий (create, update)
#
class Admin::PoiCategoriesController < Admin::BaseController
  PER_PAGE = 20

  # Pundit: policy_scope не нужен для create/update/new
  # и для экшенов картинки-маркера (map_icon) / import_pbf — единичный ресурс
  skip_after_action :verify_policy_scoped, only: %i[create update new update_category_icon remove_category_icon import_pbf]

  #
  # Отображает список категорий POI
  #
  def index
    authorize PoiCategory, :index?

    @pagy, @categories = pagy(filtered_categories, limit: PER_PAGE)
  end

  #
  # Отображает форму создания новой категории
  #
  def new
    authorize PoiCategory, :create?

    @category = PoiCategory.new
  end

  #
  # Отображает детальную страницу категории с полями
  #
  def show
    @category = PoiCategory.friendly.find(params[:id])
    authorize @category, :show?

    @edit_mode = params[:edit] == "true"
    @fields = @category.poi_category_fields.by_position
    # Аудити категории и её полей (PoiCategoryField) — единая лента изменений
    @versions = PoiCategoryService.audit_versions(category: @category).order(created_at: :desc)
    @pagy_audit, @versions = pagy(@versions, limit: 10, page: params[:audit_page] || 1)

    # POI категории с пагинацией (вкладка POIs)
    @pagy_pois, @pois = pagy(
      @category.pois.includes(:user).order(created_at: :desc),
      limit: 10,
      page: params[:pois_page] || 1
    )
  end

  #
  # Создаёт новую категорию POI
  #
  def create
    authorize PoiCategory, :create?

    @category = PoiCategoryService.create(
      params: category_params,
      current_user: current_user
    )

    redirect_to admin_poi_category_path(id: @category), notice: t("admin.poi_categories.create_success")
  rescue PoiCategoryService::CreateError => e
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  #
  # Обновляет категорию POI
  #
  def update
    @category = PoiCategory.friendly.find(params[:id])
    authorize @category, :update?

    PoiCategoryService.update(
      category: @category,
      params: category_params,
      current_user: current_user
    )

    redirect_to admin_poi_category_path(id: @category), notice: t("admin.poi_categories.update_success")
  rescue PoiCategoryService::UpdateError => e
    flash.now[:alert] = e.message
    render :show, status: :unprocessable_entity
  end

  #
  # POST /admin-panel/poi_categories/:id/map_icon
  #
  # Загружает и прикрепляет картинку-маркер категории (category_icon).
  # HTTP/multipart (fetch) — бинарники через Reflex не передаются.
  # Live-обновление карточки/маркеров — через PoiCategoryBroadcaster
  # (PaperTrail → VersionObserverJob).
  #
  # @return [JSON] { url:, attached: true } при успехе
  #
  def update_category_icon
    @category = PoiCategory.friendly.find(params[:id])
    authorize @category, :update?

    file = params[:category][:category_icon] if params[:category].present?
    return render json: { error: t("admin.poi_categories.category_icons.file_required") }, status: :unprocessable_entity if file.blank?

    PoiCategoryService.attach_category_icon(category: @category, file: file, current_user: current_user)
    render json: { url: @category.category_icon_url, attached: true }, status: :ok
  rescue Pundit::NotAuthorizedError => e
    render json: { error: t("admin.poi_categories.category_icons.unauthorized") }, status: :forbidden
  rescue PoiCategoryService::UpdateError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  #
  # DELETE /admin-panel/poi_categories/:id/map_icon
  #
  # Удаляет картинку-маркер категории. После удаления карта рендерит
  # MDI-иконку (fallback).
  #
  # @return [JSON] { ok: true } при успехе
  #
  def remove_category_icon
    @category = PoiCategory.friendly.find(params[:id])
    authorize @category, :update?

    PoiCategoryService.remove_category_icon(category: @category, current_user: current_user)
    render json: { ok: true }, status: :ok
  rescue Pundit::NotAuthorizedError => e
    render json: { error: t("admin.poi_categories.category_icons.unauthorized") }, status: :forbidden
  rescue PoiCategoryService::UpdateError => e
    render json: { error: e.message }, status: :unprocessable_entity
  end

  #
  # POST /admin-panel/poi_categories/:id/import_pbf
  #
  # Принимает загруженный .osm.pbf файл, сохраняет его во временный файл
  # и ставит фоновый OsmPbfImportJob (SolidQueue). Файл удаляется джобом в ensure.
  #
  # @return [JSON] { enqueued: true, file_path: String } при успехе
  #
  def import_pbf
    @category = PoiCategory.friendly.find(params[:id])
    authorize @category, :update?

    file = params[:poi_category][:pbf_file] if params[:poi_category].present?
    return render json: { error: t("admin.poi_categories.pbf_import.file_required") }, status: :unprocessable_entity if file.blank?

    file_path = store_pbf_file(file)
    OsmPbfImportJob.perform_later(@category.id, file_path, current_user.id)

    render json: { enqueued: true, file_path: File.basename(file_path) }, status: :ok
  rescue Pundit::NotAuthorizedError
    render json: { error: t("admin.poi_categories.pbf_import.unauthorized") }, status: :forbidden
  rescue PbfImportError => e
    render json: { error: e.message }, status: :unprocessable_entity
  rescue StandardError => e
    Rails.logger.error "import_pbf error: #{e.class} #{e.message}"
    render json: { error: t("admin.poi_categories.pbf_import.generic_error") }, status: :internal_server_error
  end

  private

  #
  # Разрешенные параметры для категории
  #
  # @return [ActionController::Parameters]
  #
  def category_params
    # Мультиязычные поля (name/description/osm_default_name) — вложенные Hash
    # (JSONB). .to_h рекурсивно приводит вложенные Parameters к Hash, иначе
    # PoiCategoryService.create падает с ActionController::UnfilteredParameters.
    params.require(:poi_category).permit(
      :slug, :icon, :position, :active, :osm_tags,
      name: I18n.available_locales.map(&:to_s),
      description: I18n.available_locales.map(&:to_s),
      osm_default_name: I18n.available_locales.map(&:to_s)
    ).to_h
  end

  #
  # Возвращает отфильтрованный список категорий
  #
  # @return [ActiveRecord::Relation]
  #
  def filtered_categories
    categories = PoiCategory.all

    categories = categories.where(active: params[:active]) if params[:active].present?

    if params[:q].present?
      query = "%#{params[:q]}%"
      categories = categories.where("name->>'en' ILIKE ? OR name->>'ru' ILIKE ? OR slug ILIKE ?", query, query, query)
    end

    categories.order(position: :asc)
  end

  #
  # Сохраняет загруженный .pbf файл во временный каталог и возвращает путь.
  # Контролирует расширение и размер (защита от мусора/гигантских файлов).
  #
  # @param file [ActionDispatch::Http::UploadedFile] загруженный .pbf файл
  # @return [String] абсолютный путь к сохранённому файлу
  # @raise [PbfImportError] если файл невалиден
  #
  def store_pbf_file(file)
    unless %w[.pbf .osm.pbf .osmpbf].include?(File.extname(file.original_filename).downcase)
      raise PbfImportError, t("admin.poi_categories.pbf_import.invalid_extension")
    end

    dir = Rails.root.join("tmp", "pbf_imports")
    FileUtils.mkdir_p(dir)

    dest = dir.join("#{SecureRandom.uuid}.osm.pbf")
    # IO.copy_stream — стриминг без загрузки всего файла в память
    # (региональные .pbf могут быть 10+ ГБ)
    IO.copy_stream(file.path, dest)
    dest.to_s
  end

  # Ошибка импорта .pbf (ограничения файла)
  class PbfImportError < StandardError; end
end
