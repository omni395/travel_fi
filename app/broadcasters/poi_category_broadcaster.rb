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

  # События категории, для которых рассылаются уведомления (PoiCategoryNotification)
  # по личным настройкам получателей. Для остальных — только live-обновление UI.
  NOTIFICATION_EVENTS = %w[osm_import].freeze

  #
  # Отправляет обновление категории POI через WebSocket
  #
  # @param category [PoiCategory] обновленная категория
  # @param event_type [String] ключ события ("update", "create", "osm_import", ...)
  # @param payload [Hash] контекст события { stats:, initiator_id: }
  #
  def self.call(category:, event_type: "update", payload: {})
    new(category: category, event_type: event_type, payload: payload).broadcast
  end

  attr_reader :category, :event_type, :payload

  def initialize(category:, event_type: "update", payload: {})
    @category = category
    @event_type = event_type
    @payload = payload
  end

  #
  # Выполняет broadcast обновления всех зон категории в общий поток админки
  # "admin_feed" (все подписанные админы; см. README «Канальная модель»).
  #
  # События, для которых НЕ перерисовываем карточку (#poi-category-detail).
  # Для "category_icon" картинка — актив: её замена уже обработана клиентом
  # (JSON url → превью), а полный рендер show-компонента в контейнер затирает
  # OPEN-форму редактирования (обёртка #poi-category-detail содержит либо show,
  # либо edit в зависимости от @edit_mode).
  SKIP_DETAIL_EVENTS = %w[category_icon].freeze

  def broadcast
    # При смене картинки-маркера НЕ трогаем #poi-category-detail (затрёт форму),
    # а только перерисовываем маркеры карты (ниже). Для остальных событий —
    # полный рендер зон.
    unless SKIP_DETAIL_EVENTS.include?(event_type)
      # 1. Карточка категории
      # inner_html в #poi-category-detail (безопасен: не использует parent.children[idx])
      show_html = render_show_component
      if show_html.present?
        cable_ready["admin_feed"].inner_html(
          selector: "#poi-category-detail",
          html: show_html
        )
      end

      # 2. Список динамических полей категории
      fields_html = render_fields_component
      if fields_html.present?
        cable_ready["admin_feed"].inner_html(
          selector: "[data-poi-category-fields]",
          html: fields_html
        )
      end

      # 3. Список POI категории (первая страница)
      pois_html = render_pois_component
      if pois_html.present?
        cable_ready["admin_feed"].inner_html(
          selector: "[data-poi-category-pois]",
          html: pois_html
        )
      end

      # 4. Лента аудита (версии категории и её полей)
      audit_html = render_audit_component
      if audit_html.present?
        cable_ready["admin_feed"].inner_html(
          selector: "[data-audit-log]",
          html: audit_html
        )
      end

      cable_ready["admin_feed"].broadcast
    end

    # 5. Перерисовываем маркеры на карте у ВСЕХ пользователей через общий поток
    #    "pois_map" при любом изменении категории (update / смена картинки).
    #    detail.type "category" не даёт bbox → клиентский _detailIntersectsView
    #    считает событие релевантным и перезагружает маркеры в видимых границах
    #    (новые category_image доедут через map_feature_data → #poi-map-features).
    cable_ready["pois_map"].dispatch_event(
      name: "poi:reload-features",
      detail: { type: "category", category_id: category.id }
    )
    cable_ready["pois_map"].broadcast

    # Рассылаем уведомления (мультикаст) для событий с настроенными каналами
    notify_recipients if NOTIFICATION_EVENTS.include?(event_type)

    Rails.logger.info("PoiCategoryBroadcaster: Sent update for category #{category.id} (#{category.localized_name})")
  rescue StandardError => e
    Rails.logger.error("PoiCategoryBroadcaster error: #{e.class} #{e.message}")
  end

  private

  #
  # Рассылает уведомления о событии категории инициатору и всем админам.
  # Для КАЖДОГО получателя каналы фильтруются по его Setting внутри
  # PoiCategoryNotification (deliver_by ... if:). Каналы настраиваются колонками
  # "#{event_type}_*_enabled" (например osm_import_notifications_enabled).
  #
  def notify_recipients
    initiator = User.find_by(id: payload[:initiator_id])
    recipients = [ initiator, *User.with_role(:admin) ].compact.uniq

    recipients.each do |recipient|
      PoiCategoryNotification.with(item: category, event_type: event_type, payload: payload).deliver_later(recipient)
    end
  rescue StandardError => e
    Rails.logger.error("PoiCategoryBroadcaster#notify_recipients error: #{e.class} #{e.message}")
  end

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
