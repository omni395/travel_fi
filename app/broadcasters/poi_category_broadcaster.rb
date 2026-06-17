# frozen_string_literal: true

#
# PoiCategoryBroadcaster - отправляет обновления категорий POI через WebSocket
#
# Ответственность:
# 1. Получает обновленную категорию POI
# 2. Формирует CableReady команды для обновления UI в админке
# 3. Отправляет команды в AdminChannel
#
class PoiCategoryBroadcaster
  include CableReady::Broadcaster

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
  # Выполняет broadcast обновления
  #
  def broadcast
    # Морфим строку категории в таблице админки
    component = Admin::PoiCategory::ShowComponent.new(category: category)
    html = ApplicationController.render(component, layout: false)

    cable_ready["AdminChannel"].morph(
      selector: "[data-admin-poi-category-id='#{category.id}']",
      html: html
    )

    cable_ready["AdminChannel"].broadcast

    Rails.logger.info("PoiCategoryBroadcaster: Sent update for category #{category.id} (#{category.localized_name})")
  rescue StandardError => e
    Rails.logger.error("PoiCategoryBroadcaster error: #{e.class} #{e.message}")
  end
end
