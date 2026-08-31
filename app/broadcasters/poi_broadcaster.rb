# frozen_string_literal: true

#
# PoiBroadcaster - отправляет обновления POI через WebSocket
#
# Ответственность:
# 1. Получает обновленный POI
# 2. Рендерит актуальный компонент интерфейса
# 3. Формирует CableReady команды для обновления DOM
# 4. Отправляет команды в каналы пользователей
#
class PoiBroadcaster
  include CableReady::Broadcaster

  #
  # Отправляет обновление POI через WebSocket
  #
  # @param poi [Poi] POI с обновленными данными
  # @param change_status [Boolean] true, если это переход статуса (pending→approved
  #   и т.п.). В этом случае дополнительно рисуем feature-ноду точки в скрытый
  #   контейнер #poi-map-features — иначе одобренная точка долго не появляется
  #   на карте у пользователя (подробнее: см. _onReloadFeatures в map_component_controller).
  #
  def self.call(poi:, change_status: false)
    new(poi: poi, change_status: change_status).broadcast
  end

  attr_reader :poi, :change_status

  #
  # Конструктор бродкастера
  #
  # @param poi [Poi] POI с обновленными данными
  # @param change_status [Boolean] флаг перехода статуса (см. self.call)
  #
  def initialize(poi:, change_status: false)
    @poi = poi
    @change_status = change_status
  end

  #
  # Выполняет broadcast обновления
  #
  # ВАЖНО: рендер может упасть с Warden error (Devise без request в SolidQueue).
  # Каждый рендер обёрнут в rescue, broadcast вызывается в любом случае.
  #
  def broadcast
    # Рендерим компоненты (могут упасть — возвращаем пустую строку)
    card_html = render_poi_list_item_component
    toast_html = render_toast
    admin_table_html = render_admin_table

    # 1. Админка: live-обновление таблицы POI [data-admin-pois-list] (create
    #    и change_status). Админ Б видит новый pending-рядо и смену статуса
    #    без перезагрузки — аналогично Admin::UserBroadcaster.
    if admin_table_html.present?
      cable_ready["admin_feed"].inner_html(
        selector: "[data-admin-pois-list]",
        html: admin_table_html
      )
    end

    # 1b. Обновление элемента POI в списке сайдбара пользовательской карты.
    # inner_html (НЕ morph — morph падает на undefined.dispatchEvent в CableReady).
    # Уходит в общий поток карты "pois_map": каждый пользователь на карте
    # (через UserChannel: stream_from "pois_map") получает live-обновление.
    if card_html.present?
      cable_ready["pois_map"].inner_html(
        selector: "[data-poi-id='#{poi.id}']",
        html: card_html
      )
    end

    # 2. Toast-уведомление (не сохраняем здесь — тосты адресуются персонально
    #    в user_N через ToastBroadcaster; общая карта не должна спамить тостами).

    # 3. Шапка POI для админов ("admin_feed") — обёртка #poi-detail в show.html.erb.
    #    Раньше это делал Reflex через morph "#poi-detail"; теперь — только через
    #    Broadcaster, чтобы live-обновление видели ВСЕ подписанные админы.
    header_html = render_poi_header_component
    if header_html.present?
      cable_ready["admin_feed"].inner_html(
        selector: "#poi-detail",
        html: header_html
      )
    end

    # 3b. Содержимое таба Details (ShowComponent) — отдельная обёртка
    #    [data-poi-detail-body] в show.html.erb. inner_html (НЕ morph — падает
    #    на undefined.dispatchEvent в CableReady). Два селектора-цели НЕ вложены
    #    друг в друга (догма), поэтому обновляются независимо.
    show_html = render_poi_show_component
    if show_html.present?
      cable_ready["admin_feed"].inner_html(
        selector: "[data-poi-detail-body]",
        html: show_html
      )
    end

    # 4. Лента аудита POI для админов ("admin_feed")
    audit_html = render_audit_component
    if audit_html.present?
      cable_ready["admin_feed"].inner_html(
        selector: "[data-audit-log]",
        html: audit_html
      )
    end

    # 5. Триггерим перезагрузку маркеров на карте у ВСЕХ пользователей карты —
    #    через общий поток "pois_map" (не мёртвый "UserChannel"). В detail
    #    передаём координаты POI: клиент перезагружает только если его видимые
    #    границы содержат точку (_detailIntersectsView).
    #
    # 5b. При переходе статуса (change_status) гарантируем наличие feature-ноды
    #     точки в скрытом контейнере #poi-map-features ДО перезапроса. Иначе
    #     клиентский _loadPoisInBounds() перезапрашивает, а маркер рисуется только
    #     из #poi-map-features — при сработавшем гварде _detailIntersectsView маркер
    #     не появится без перезагрузки страницы. append (не inner_html): inner_html
    #     по [data-poi-id] заменил бы и карточку сайдбара. Дубли здесь безопасны —
    #     следующий load_pois_in_bounds перезапишет #poi-map-features целиком.
    if change_status
      cable_ready["pois_map"].append(
        selector: "#poi-map-features",
        html: feature_node_html
      )
    end

    cable_ready["pois_map"].dispatch_event(
      name: "poi:reload-features",
      detail: { type: "single", lat: poi.latitude, lng: poi.longitude }
    )

    # Применяем изменения — ВСЕГДА
    cable_ready["pois_map"].broadcast
    cable_ready["admin_feed"].broadcast

    Rails.logger.info("PoiBroadcaster: Sent update for POI #{poi.id} (#{poi.name})")
  rescue StandardError => e
    Rails.logger.error("PoiBroadcaster error: #{e.class} #{e.message}")
  end

  private

  #
  # Рендерит компонент Poi::ListItemComponent
  # Может упасть с Warden error в SolidQueue — возвращает пустую строку
  #
  # @return [String] HTML строка компонента
  #
  def render_poi_list_item_component
    # Рендер верхнего уровня в SolidQueue worker: ApplicationController.render с
    # layout:false (вложенные компоненты внутри рендерятся через view_context).
    # renderer.render (layout по умолчанию) без request возвращает "" в worker.
    ApplicationController.render(Poi::ListItemComponent.new(list_item: poi), layout: false)
  rescue StandardError => e
    Rails.logger.error("Failed to render Poi::ListItemComponent: #{e.class} #{e.message}")
    ""
  end

  #
  # Рендерит Toast-уведомление
  # Может упасть с Warden error в SolidQueue — возвращает пустую строку
  #
  # @return [String] HTML строка тоста
  #
  def render_toast
    ApplicationController.render(Ui::ToastComponent.new(
      message: I18n.t("notifications.poi_updated", name: poi.name)
    ), layout: false)
  rescue StandardError => e
    Rails.logger.error("Failed to render toast: #{e.class} #{e.message}")
    ""
  end

  #
  # Рендерит шапку POI для админки (AdminChannel, #poi-detail).
  # Одиночный рендер через renderer допустим (аналог ShowComponent);
  # сбой — пустая строка, broadcast продолжается.
  #
  # @return [String] HTML строка HeaderComponent
  #
  def render_poi_header_component
    ApplicationController.render(Admin::Pois::Poi::HeaderComponent.new(poi: poi), layout: false)
  rescue StandardError => e
    Rails.logger.error("Failed to render Admin::Pois::Poi::HeaderComponent: #{e.class} #{e.message}")
    ""
  end

  #
  # Рендерит содержимое таба Details POI для админки (AdminChannel,
  # [data-poi-detail-body]).
  # Одиночный рендер через renderer допустим (аналог ListItemComponent);
  # сбой — пустая строка, broadcast продолжается.
  #
  # @return [String] HTML строка ShowComponent
  #
  def render_poi_show_component
    ApplicationController.render(Admin::Pois::Poi::ShowComponent.new(poi: poi), layout: false)
  rescue StandardError => e
    Rails.logger.error("Failed to render Admin::Pois::Poi::ShowComponent: #{e.class} #{e.message}")
    ""
  end

  #
  # Рендерит актуальную таблицу POI для админки (AdminChannel).
  # Список соответствует дефолтному индексу (свежие сверху) — пагинация не
  # применяется в фоновом job (нет request); рендерим без pagy.
  # Рендер из SolidQueue worker через ApplicationController.render верхнего уровня.
  #
  # @return [String] HTML таблицы POI
  #
  def render_admin_table
    pois = Poi.includes(:poi_category, :user).order(created_at: :desc).limit(20)
    ApplicationController.render(Admin::Pois::TableComponent.new(pois: pois, pagy: nil), layout: false)
  rescue StandardError => e
    Rails.logger.error("PoiBroadcaster render_admin_table: #{e.class} #{e.message}")
    ""
  end

  #
  # Рендерит ленту аудита POI (версии PaperTrail) для админки.
  # Может упасть с Warden error в SolidQueue — возвращает пустую строку.
  #
  # @return [String] HTML ленты аудита
  #
  def render_audit_component
    versions = poi.versions.order(created_at: :desc).limit(10)

    html = +""
    if versions.any?
      versions.each do |v|
        # Per-entry устойчивость: битая версия (например, удалённая модель) не
        # роняет рендер всей ленты (см. AuditLogComponent#render_entries_html).
        begin
          html << ApplicationController.render(Ui::AuditEntryComponent.new(version: v), layout: false)
        rescue StandardError => e
          Rails.logger.error("Failed to render POI audit entry #{v.id}: #{e.class} #{e.message}")
        end
      end
    else
      html << ApplicationController.render(Ui::AuditEntryComponent.new(version: nil), layout: false)
    end
    html
  rescue StandardError => e
    Rails.logger.error("Failed to render POI audit: #{e.class} #{e.message}")
    ""
  end

  #
  # Строит HTML feature-ноды точки для скрытого контейнера #poi-map-features.
  # Используется при change_status, чтобы гарантировать наличие маркера ДО
  # перезапроса _loadPoisInBounds(). Формат соответствует feature_html в PoiReflex.
  #
  # @return [String] HTML <div> с data-атрибутами карты
  #
  def feature_node_html
    data = PoiService.map_feature_data(poi)
    escape = ->(v) { ERB::Util.html_escape(v.to_s) }

    %(<div data-poi-id="#{escape.call(data[:id])}"
           data-poi-lat="#{escape.call(data[:lat])}"
           data-poi-lng="#{escape.call(data[:lng])}"
           data-poi-name="#{escape.call(data[:name])}"
           data-poi-icon="#{escape.call(data[:icon])}"
           data-poi-category-image="#{escape.call(data[:category_image])}"
           data-poi-category="#{escape.call(data[:category])}"
           data-poi-category-id="#{escape.call(data[:category_id])}"
           data-poi-rating="#{escape.call(data[:rating])}"
           data-poi-address="#{escape.call(data[:address])}"
           data-poi-user-id="#{escape.call(data[:user_id])}"
           data-poi-slug="#{escape.call(data[:slug])}"
           data-poi-photo="#{escape.call(data[:photo])}"></div>)
  end
end
