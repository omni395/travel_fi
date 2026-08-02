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
  #
  def self.call(poi:)
    new(poi: poi).broadcast
  end

  attr_reader :poi

  def initialize(poi:)
    @poi = poi
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

    # 1. Обновление элемента POI в списке сайдбара
    cable_ready[UserChannel].morph(
      selector: "[data-poi-id='#{poi.id}']",
      html: card_html
    )

    # 2. Toast-уведомление (если удалось отрендерить)
    if toast_html.present?
      cable_ready[UserChannel].insert_adjacent_html(
        selector: "#notifications",
        position: "beforeend",
        html: toast_html
      )
    end

    # 3. Лента аудита POI для админов (AdminChannel)
    audit_html = render_audit_component
    if audit_html.present?
      cable_ready["AdminChannel"].morph(
        selector: "[data-audit-log]",
        html: audit_html
      )
    end

    # 4. Триггерим перезагрузку маркеров на карте — ВСЕГДА
    cable_ready["UserChannel"].dispatch_event(
      name: "poi:reload-features"
    )

    # Применяем изменения — ВСЕГДА
    cable_ready[UserChannel].broadcast
    cable_ready["AdminChannel"].broadcast

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
    component = Poi::ListItemComponent.new(list_item: poi)
    ApplicationController.renderer.render(component)
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
    ApplicationController.renderer.render(Ui::ToastComponent.new(
      message: I18n.t("notifications.poi_updated", name: poi.name)
    ))
  rescue StandardError => e
    Rails.logger.error("Failed to render toast: #{e.class} #{e.message}")
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
        html << ApplicationController.render(Ui::AuditEntryComponent.new(version: v), layout: false)
      end
    else
      html << ApplicationController.render(Ui::AuditEntryComponent.new(version: nil), layout: false)
    end
    html
  rescue StandardError => e
    Rails.logger.error("Failed to render POI audit: #{e.class} #{e.message}")
    ""
  end
end
