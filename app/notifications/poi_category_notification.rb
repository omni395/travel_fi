# frozen_string_literal: true

#
# PoiCategoryNotification — ЕДИНОЕ уведомление для сущности PoiCategory.
#
# Принцип «одна сущность = один сервис/нотификация/бродкастер»:
# все события категории (создание, обновление, OSM-импорт) доставляются
# через этот класс с параметром event_type.
#
# Доставка — МУЛЬТИКАСТ: всем админам + инициатору события. Для КАЖДОГО
# получателя каналы фильтруются ПО ЕГО ЛИЧНЫМ настройкам (Setting) через
# SettingFilterable с ключом события "osm_import" (для импорта) либо по
# мастер-флагам по умолчанию.
#
# @param item [PoiCategory] категория
# @param event_type [String] ключ события ("osm_import", "create", "update", ...)
# @param payload [Hash] контекст события (например { stats:, initiator_id: })
#
class PoiCategoryNotification < ApplicationNotification
  include SettingFilterable

  # Для событий импорта используем колонки osm_import_* (профиль админа);
  # для общих событий категории (create/update) — только мастер-флаги.
  self.setting_event_key = "osm_import"

  # deliver_by :database deprecated в Noticed 3 — записи создаются автоматически
  deliver_by :email, mailer: "UserMailer", method: :osm_import_complete, if: :email_enabled?
  deliver_by :action_cable, channel: "UserChannel", stream: :user_stream, message: :to_websocket, if: :notifications_enabled?
  deliver_by :web_push, class: "Noticed::DeliveryMethods::WebPush", if: :push_enabled?

  required_param :item
  required_param :event_type
  required_param :payload

  ALLOWED_EVENT_TYPES = %w[osm_import create update].freeze

  #
  # Текст уведомления (in-app, вебсокет).
  #
  # @return [String]
  #
  def message
    case params[:event_type].to_s
    when "osm_import"
      I18n.t("notifications.osm_import_complete", count: stats[:created].to_i, category: params[:item].localized_name)
    else
      I18n.t("notifications.poi_category_updated", category: params[:item].localized_name)
    end
  end

  #
  # Сообщение для WebSocket-канала (UserChannel).
  #
  # @return [Hash]
  #
  def to_websocket
    {
      title: title_text,
      message: message,
      item_id: params[:item].id,
      event_type: params[:event_type]
    }
  end

  #
  # Персональный стрим получателя.
  #
  # @return [String]
  #
  def user_stream
    "user_#{recipient.id}"
  end

  private

  #
  # Заголовок уведомления (в т.ч. для вебсокета).
  #
  # @return [String]
  #
  def title_text
    if params[:event_type].to_s == "osm_import"
      I18n.t("notifications.osm_import_complete_title")
    else
      I18n.t("notifications.poi_category_updated_title")
    end
  end

  #
  # Статистика из payload (для события импорта).
  #
  # @return [Hash]
  #
  def stats
    params[:payload].is_a?(Hash) ? params[:payload].fetch(:stats, {}) : {}
  end
end
