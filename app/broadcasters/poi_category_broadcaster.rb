# frozen_string_literal: true

#
# PoiCategoryBroadcaster - отправляет обновления категорий POI через WebSocket
#
# Ответственность:
# 1. Получает обновленную категорию POI
# 2. Формирует CableReady команды для обновления UI в админке
# 3. Обновляет ВСЕ зоны отображения категории:
#    - карточку категории (ShowComponent)
#    - список динамических полей (FieldsListComponent)
#    - ленту аудита (Ui::AuditEntryComponent)
# 4. Отправляет команды в AdminChannel
#
# ВАЖНО: рендер из фонового job (SolidQueue) может упасть с Warden error —
# каждый рендер обёрнут в rescue, broadcast выполняется всегда.
#
class PoiCategoryBroadcaster
  include CableReady::Broadcaster
  include Pagy::Method

  #
  # Отправляет обновление категории POI через WebSocket
  #
  # @param category [PoiCategory] обновленная категория
  #
  def self.call(category:)
    new(category: category).broadcast
  end

  attr_reader :category

  def initialize(category:)
    @category = category
  end

  #
  # Выполняет broadcast обновления всех зон категории в AdminChannel
  #
  def broadcast
    # 1. Карточка категории
    # inner_html в #poi-category-detail (безопасен: не использует parent.children[idx])
    show_html = render_show_component
    if show_html.present?
      cable_ready["AdminChannel"].inner_html(
        selector: "#poi-category-detail",
        html: show_html
      )
    end

    # 2. Список динамических полей категории
    fields_html = render_fields_component
    if fields_html.present?
      cable_ready["AdminChannel"].inner_html(
        selector: "[data-poi-category-fields]",
        html: fields_html
      )
    end

    # 3. Список POI категории (первая страница)
    pois_html = render_pois_component
    if pois_html.present?
      cable_ready["AdminChannel"].inner_html(
        selector: "[data-poi-category-pois]",
        html: pois_html
      )
    end

    # 4. Лента аудита (версии категории и её полей)
    audit_html = render_audit_component
    if audit_html.present?
      cable_ready["AdminChannel"].inner_html(
        selector: "[data-audit-log]",
        html: audit_html
      )
    end

    cable_ready["AdminChannel"].broadcast

    Rails.logger.info("PoiCategoryBroadcaster: Sent update for category #{category.id} (#{category.localized_name})")
  rescue StandardError => e
    Rails.logger.error("PoiCategoryBroadcaster error: #{e.class} #{e.message}")
  end

  private

  #
  # request для pagy() в SolidQueue worker (аналог того, что Reflex получает от
  # StimulusReflex). Pagy::Method#pagy вызывает self.request (options[:request] ||= request);
  # без него в job падает NameError "undefined local variable or method 'request'",
  # и зоны с пагинацией (POIs, Audit) не отправляются в broadcast.
  # Pagy затем заменяет заглушку на Pagy::Request.
  #
  # @return [ActionDispatch::Request] заглушка запроса
  #
  def request
    @request ||= ActionDispatch::Request.new({})
  end

  #
  # Рендерит карточку категории (ShowComponent)
  #
  # @return [String] HTML компонента
  #
  def render_show_component
    component = Admin::PoiCategories::PoiCategory::ShowComponent.new(category: category)
    ApplicationController.render(component, layout: false)
  rescue StandardError => e
    Rails.logger.error("PoiCategoryBroadcaster: show render failed: #{e.class} #{e.message}")
    ""
  end

  #
  # Рендерит список полей категории (FieldsListComponent)
  #
  # @return [String] HTML компонента
  #
  def render_fields_component
    component = Admin::PoiCategories::PoiCategory::FieldsListComponent.new(category: category)
    ApplicationController.render(component, layout: false)
  rescue StandardError => e
    Rails.logger.error("PoiCategoryBroadcaster: fields render failed: #{e.class} #{e.message}")
    ""
  end

  #
  # Рендерит список POI категории (первая страница пагинации).
  #
  # @return [String] HTML компонента списка POI
  #
  def render_pois_component
    # pagy helper (Pagy::Method): в Pagy 43.6.1 прямой Pagy.new(count:, limit:) бросает ArgumentError
    pagy, pois = pagy(category.pois.includes(:user).order(created_at: :desc), limit: 10, page: 1)
    component = Admin::PoiCategories::PoiCategory::PoisListComponent.new(
      category: category,
      pagy: pagy,
      pois: pois
    )
    ApplicationController.render(component, layout: false)
  rescue StandardError => e
    Rails.logger.error("PoiCategoryBroadcaster: pois render failed: #{e.class} #{e.message}")
    ""
  end

  #
  # Рендерит ленту аудита через AuditLogComponent (вкладка Audit Log).
  # Рендер идентичен Reflex#audit_page — единый компонент исключает расхождение.
  #
  # @return [String] HTML ленты аудита
  #
  def render_audit_component
    # Первая страница ленты аудита (с пагинацией, чтобы не стирать её при inner_html)
    versions_relation = PoiCategoryService.audit_versions(category: category).order(created_at: :desc)
    pagy, versions = pagy(versions_relation, limit: 10, page: 1)

    ApplicationController.render(
      Admin::PoiCategories::PoiCategory::AuditLogComponent.new(category: category, versions: versions, pagy: pagy),
      layout: false
    )
  rescue StandardError => e
    Rails.logger.error("PoiCategoryBroadcaster: audit render failed: #{e.class} #{e.message}")
    ""
  end
end
