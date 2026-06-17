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
  def broadcast
    # Рендерим обновленный компонент карточки POI (элемент списка)
    card_html = render_poi_list_item_component

    # 1. Обновление элемента POI в списке сайдбара
    cable_ready[UserChannel].morph(
      selector: "[data-poi-id='#{poi.id}']",
      html: card_html
    )

    # 2. Toast-уведомление
    toast_html = ApplicationController.renderer.render(Ui::ToastComponent.new(
      message: I18n.t("notifications.poi_updated", name: poi.name)
    ))

    cable_ready[UserChannel].insert_adjacent_html(
      selector: "#notifications",
      position: "beforeend",
      html: toast_html
    )

    # Применяем изменения
    cable_ready[UserChannel].broadcast

    Rails.logger.info("PoiBroadcaster: Sent update for POI #{poi.id} (#{poi.name})")
  rescue StandardError => e
    Rails.logger.error("PoiBroadcaster error: #{e.class} #{e.message}")
  end

  private

  #
  # Рендерит компонент Poi::ListItemComponent
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
end
