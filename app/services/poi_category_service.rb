# frozen_string_literal: true

#
# PoiCategoryService - сервис для управления категориями POI
#
# Ответственность:
# 1. Создание/обновление категорий
# 2. Управление полями категорий (создание, обновление, удаление)
# 3. Поиск и фильтрация категорий
#
class PoiCategoryService
  # Разрешённые атрибуты поля категории (включая OSM-маппинг)
  FIELD_PERMITTED_KEYS = %i[
    field_key field_type label required options placeholder hint position active
    osm_keys osm_value_map osm_transform
  ].freeze

  #
  # Создаёт новую категорию POI
  #
  # @param params [Hash] параметры категории { name:, slug:, icon:, description:, position:, active: }
  # @param current_user [User] пользователь, выполняющий действие
  # @return [PoiCategory] созданная категория
  # @raise [CreateError] если произойдет ошибка валидации
  #
  def self.create(params:, current_user:)
    category = PoiCategory.new(permitted_params(params))
    category.save!
    category
  rescue ActiveRecord::RecordInvalid => e
    raise CreateError, e.message
  end

  #
  # Обновляет категорию POI
  #
  # @param category [PoiCategory] категория для обновления
  # @param params [Hash] параметры для обновления
  # @param current_user [User] пользователь, выполняющий действие
  # @return [PoiCategory] обновленная категория
  # @raise [UpdateError] если произойдет ошибка валидации
  #
  def self.update(category:, params:, current_user:)
    category.update!(permitted_params(params))
    category
  rescue ActiveRecord::RecordInvalid => e
    raise UpdateError, e.message
  end

  #
  # Удаляет категорию POI вместе с её динамическими полями (dependent: :destroy)
  #
  # @param category [PoiCategory] категория для удаления
  # @param current_user [User] пользователь, выполняющий действие
  # @raise [DestroyError] если не удалось удалить (например, есть POI — restrict_with_error)
  #
  def self.destroy(category:, current_user:)
    PaperTrail.request.whodunnit = current_user&.id&.to_s
    category.destroy!
    true
  rescue StandardError => e
    raise DestroyError, e.message
  end

  #
  # Создаёт поле для категории POI
  #
  # @param category [PoiCategory] категория
  # @param params [Hash] параметры поля { field_key:, field_type:, label:, required:, options:, placeholder:, hint:, position:, active: }
  # @param current_user [User] пользователь, выполняющий действие
  # @return [PoiCategoryField] созданное поле
  # @raise [CreateError] если произойдет ошибка валидации
  #
  def self.create_field(category:, params:, current_user:)
    PoiCategoryField.transaction do
      # Страховка: гарантируем автора PaperTrail-версии независимо от контекста вызова
      # (Reflex ставит whodunnit в before_reflex, но прямые вызовы/контроллер — нет).
      PaperTrail.request.whodunnit = current_user&.id&.to_s

      field = category.poi_category_fields.new(field_params(params))
      field.save!
      renumber_positions(category)
      field
    end
  rescue ActiveRecord::RecordInvalid => e
    raise CreateError, e.message
  end

  #
  # Обновляет поле категории POI
  #
  # @param field [PoiCategoryField] поле для обновления
  # @param params [Hash] параметры для обновления
  # @param current_user [User] пользователь, выполняющий действие
  # @return [PoiCategoryField] обновленное поле
  # @raise [UpdateError] если произойдет ошибка валидации
  #
  def self.update_field(field:, params:, current_user:)
    # Страховка автора PaperTrail-версии (см. create_field)
    PaperTrail.request.whodunnit = current_user&.id&.to_s
    field.update!(field_params(params))
    field
  rescue ActiveRecord::RecordInvalid => e
    raise UpdateError, e.message
  end

  #
  # Удаляет поле категории POI
  #
  # @param field [PoiCategoryField] поле для удаления
  # @param current_user [User] пользователь, выполняющий действие
  # @raise [DestroyError] если произойдет ошибка
  #
  def self.destroy_field(field:, current_user:)
    category = field.poi_category
    PoiCategoryField.transaction do
      # Страховка автора PaperTrail-версии (см. create_field)
      PaperTrail.request.whodunnit = current_user&.id&.to_s
      field.destroy!
      renumber_positions(category)
    end
  rescue ActiveRecord::RecordNotDestroyed => e
    raise DestroyError, e.message
  end

  #
  # Перемещает поле вверх или вниз по позиции
  #
  # @param field [PoiCategoryField] поле
  # @param direction [String] "up" или "down"
  #
  def self.reorder_field(field:, direction:)
    category = field.poi_category
    fields = category.poi_category_fields.by_position.to_a
    idx = fields.index { |f| f.id == field.id }
    return unless idx

    swap_idx = direction == "up" ? idx - 1 : idx + 1
    return if swap_idx < 0 || swap_idx >= fields.size

    current_pos = fields[idx].position
    target_pos = fields[swap_idx].position

    # update! (а не update_all): создаёт PaperTrail-версии, что триггерит
    # VersionObserverJob → Broadcaster (Database-Triggered Architecture из README).
    # Автор (whodunnit) уже проставлен в ApplicationReflex#before_reflex.
    fields[idx].update!(position: target_pos)
    fields[swap_idx].update!(position: current_pos)
  rescue ActiveRecord::RecordInvalid => e
    raise UpdateError, e.message
  end

  #
  # Пересчитывает позиции полей категории последовательно (1..N) через update!.
  # Создаёт PaperTrail-версии → VersionObserverJob → Broadcaster.
  #
  # @param category [PoiCategory] категория
  #
  def self.renumber_positions(category)
    category.poi_category_fields.by_position.each_with_index do |field, idx|
      target = idx + 1
      field.update!(position: target) unless field.position == target
    end
  end

  #
  # Ищет категории по запросу через Ransack
  #
  # @param query [String, nil] поисковый запрос
  # @param active [Boolean, nil] фильтр по активности
  # @return [ActiveRecord::Relation] отфильтрованные категории
  #
  def self.search_categories(query: nil, active: nil)
    categories = PoiCategory.all

    conditions = {}
    conditions[:name_cont] = query if query.present?
    conditions[:active_eq] = active if active.present?

    result = categories.ransack(conditions).result
    result.order(position: :asc)
  end

  #
  # Возвращает объединённую ленту аудита категории: версии самой категории
  # и версии её полей (PoiCategoryField), включая удалённые поля.
  #
  # Версии полей хранятся отдельно от версий категории (has_paper_trail на поле).
  # Для удалённых полей (item уже отсутствует в БД) принадлежность к категории
  # определяется через object (JSON в text-колонке): object["poi_category_id"].
  #
  # @param category [PoiCategory] категория
  # @return [ActiveRecord::Relation] relation версий (сортировка — на стороне вызова)
  #
  def self.audit_versions(category:)
    current_field_ids = category.poi_category_fields.ids

    # ID удалённых полей категории: object (JSON в text-колонке) содержит poi_category_id.
    # object может быть nil (версия без снапшота) или уже Hash (после десериализации) —
    # безопасно обрабатываем оба варианта через parse_version_object.
    removed_field_ids = PaperTrail::Version
                        .where(item_type: "PoiCategoryField")
                        .where.not(item_id: current_field_ids)
                        .pluck(:item_id, :object)
                        .filter_map do |item_id, object|
      parsed = parse_version_object(object)
      item_id if parsed.is_a?(Hash) && parsed["poi_category_id"] == category.id
    end

    all_field_ids = (current_field_ids + removed_field_ids).uniq

    versions = PaperTrail::Version.where(item_type: "PoiCategory", item_id: category.id)
    if all_field_ids.any?
      versions = versions.or(
        PaperTrail::Version.where(item_type: "PoiCategoryField", item_id: all_field_ids)
      )
    end

    versions
  end

  #
  # Безопасно приводит object версии к Hash.
  # PaperTrail с JSON-сериализатором хранит object JSON-строкой в text-колонке,
  # но при чтении через модель может вернуть уже десериализованный Hash,
  # а для некоторых версий object может быть nil.
  #
  # @param raw [String, Hash, nil] сырое значение колонки object
  # @return [Hash, nil] распарсенный объект или nil
  #
  def self.parse_version_object(raw)
    return nil if raw.blank?
    return raw if raw.is_a?(Hash)

    JSON.parse(raw) if raw.is_a?(String)
  rescue JSON::ParserError
    nil
  end

  # Допустимые content_type для картинки-маркера категории
  CATEGORY_ICON_TYPES = %w[image/jpeg image/png image/webp image/svg].freeze

  #
  # Обрабатывает, прикрепляет и заменяет картинку-маркер категории
  # (category_icon). Использует PhotoService для resize/сжатия/webp.
  #
  # ВАЖНО: картинка — ActiveStorage-актив, а не поле модели. Аудит её изменений
  # через category.touch дал бы ПУСТУЮ PaperTrail-версию (меняется только
  # updated_at), которая бессмысленна на ленте аудита. Более того, touch →
  # VersionObserverJob → PoiCategoryBroadcaster затирает карточку категории
  # (#poi-category-detail) show-компонентом, что затирает форму редактирования.
  # Поэтому картинка управляется напрямую через PoiCategoryBroadcaster с
  # event_type "category_icon" (без полного рендера зон, см. broadcaster).
  #
  # @param category [PoiCategory] категория POI
  # @param file [ActionDispatch::Http::UploadedFile] файл картинки
  # @param current_user [User] пользователь, выполняющий действие
  # @return [PoiCategory] обновлённая категория
  # @raise [UpdateError] если файл невалиден или не удалось обработать
  #
  def self.attach_category_icon(category:, file:, current_user:)
    raise UpdateError, I18n.t("poi_category_service.errors.invalid_icon") unless valid_category_icon_file?(file)

    processed = PhotoService.process(
      file,
      filename: "category_icon_#{category.id}.webp",
      max_dimension: 512,
      format: "webp"
    )

    # Картинка-маркер — ActiveStorage-актив, а не поле модели. Пустая
    # PaperTrail-версия от touch родителя (один updated_at) игнорируется в
    # VersionObserverJob. Явную аудит-версию ("кто загрузил иконку") пишем
    # отдельно через PaperTrailAuditService (событие audit-only, broadcast
    # маркеров — ниже через event_type "category_icon").
    ActiveRecord::Base.transaction do
      category.category_icon.detach if category.category_icon.attached?
      category.category_icon.attach(
        io: processed,
        filename: "category_icon_#{category.id}_#{SecureRandom.hex(4)}.webp",
        content_type: "image/webp"
      )
    end

    PaperTrailAuditService.log_category_icon_uploaded(category, current_user)
    PoiCategoryBroadcaster.call(category: category, event_type: "category_icon")
    category
  rescue StandardError => e
    Rails.logger.warn("PoiCategoryService attach_category_icon failed: #{e.message}")
    raise UpdateError, e.message
  end

  #
  # Удаляет картинку-маркер категории (category_icon).
  # Аналогично attach — напрямую через PoiCategoryBroadcaster (event_type
  # "category_icon"), без пустой PaperTrail-версии и без затирания формы.
  # Клиент уже получил success из JSON и сбросил превью на MDI-иконку.
  #
  # @param category [PoiCategory] категория POI
  # @param current_user [User] пользователь, выполняющий действие
  # @return [Boolean] true если картинка была удалена
  #
  def self.remove_category_icon(category:, current_user:)
    return false unless category.category_icon.attached?

    ActiveRecord::Base.transaction do
      category.category_icon.purge_later
    end

    PaperTrailAuditService.log_category_icon_removed(category, current_user)
    PoiCategoryBroadcaster.call(category: category, event_type: "category_icon")
    true
  rescue StandardError => e
    Rails.logger.warn("PoiCategoryService remove_category_icon failed: #{e.message}")
    raise UpdateError, e.message
  end

  #
  # Валидирует формат файла картинки-маркера категории.
  # Допускаются: JPEG, PNG, WebP.
  #
  # @param file [Object] файл
  # @return [Boolean]
  #
  def self.valid_category_icon_file?(file)
    return false unless file
    return false unless file.respond_to?(:content_type)

    CATEGORY_ICON_TYPES.include?(file.content_type)
  end

  private

  #
  # Фильтрует и преобразует параметры категории
  # osm_tags: строка → массив (разделение по запятой)
  #
  # @param params [Hash]
  # @return [Hash]
  #
  def self.permitted_params(params)
    result = params.slice(:name, :slug, :icon, :description, :position, :active, :osm_default_name)

    # Парсим osm_tags: строка "amenity=toilets, amenity=shower" → ["amenity=toilets", "amenity=shower"]
    if params[:osm_tags].present?
      result[:osm_tags] = if params[:osm_tags].is_a?(String)
                            params[:osm_tags].split(",").map(&:strip).reject(&:blank?)
      elsif params[:osm_tags].is_a?(Array)
                            params[:osm_tags].map(&:strip).reject(&:blank?)
      else
                            params[:osm_tags]
      end
    end

    result
  end

  #
  # Фильтрует и нормализует параметры поля категории.
  # osm_keys/osm_value_map приходят из формы как JSON-строка или готовые структуры —
  # приводятся к jsonb-типам (Array/Hash) для безопасной записи в БД.
  #
  # @param params [Hash]
  # @return [Hash]
  #
  def self.field_params(params)
    result = params.slice(*FIELD_PERMITTED_KEYS)

    # osm_keys: строка "shower,showers" или JSON-массив → Array
    result[:osm_keys] = parse_osm_keys(params[:osm_keys]) if params.key?(:osm_keys)
    # osm_value_map: строка JSON {"fee":"yes"} → Hash
    result[:osm_value_map] = parse_osm_value_map(params[:osm_value_map]) if params.key?(:osm_value_map)

    result
  end

  #
  # Приводит osm_keys к массиву строк.
  # Поддерживает: JSON-массив (["shower","showers"]), CSV-строку ("shower, showers"),
  # уже готовый Array.
  #
  # @param value [Object]
  # @return [Array<String>]
  #
  def self.parse_osm_keys(value)
    parsed = value
    if value.is_a?(String)
      stripped = value.strip
      parsed = stripped.start_with?("[") ? JSON.parse(stripped) : stripped.split(",")
    end

    Array(parsed).map(&:to_s).map(&:strip).reject(&:blank?)
  rescue JSON::ParserError
    value.to_s.split(",").map(&:strip).reject(&:blank?)
  end

  #
  # Приводит osm_value_map к хэшу.
  # Поддерживает JSON-строку или уже готовый Hash.
  #
  # @param value [Object]
  # @return [Hash]
  #
  def self.parse_osm_value_map(value)
    return {} if value.blank?

    parsed = value.is_a?(String) ? (JSON.parse(value) rescue {}) : value
    parsed.is_a?(Hash) ? parsed : {}
  end

  # Custom exceptions
  class CreateError < StandardError; end
  class UpdateError < StandardError; end
  class DestroyError < StandardError; end
end
