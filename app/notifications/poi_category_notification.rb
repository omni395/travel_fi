# frozen_string_literal: true

#
# PoiCategoryNotification — ЕДИНОЕ уведомление для сущности PoiCategory.
#
# Принцип «одна сущность = один сервис/нотификация/бродкастер»:
# все события категории (создание, обновление, OSM-импорт) доставляются
# через этот класс с параметром event_type.
#
# Доставка — МУЛЬТИКАСТ: всем админам + инициатору события. Для КАЖДОГО
# получателя каналы фильтруются ПО ЕГО ЛИЧНЫМ настройкам (Setting):
#   - in-app (action_cable → тост)      — если "#{event_type}_notifications_enabled"
#   - email (UserMailer)                — если "#{event_type}_email_enabled"
#   - web_push                          — если "#{event_type}_push_enabled"
# База (database) сохраняется всегда (in-app список уведомлений).
#
# Сейчас настроено событие "osm_import" (колонки osm_import_* в settings).
# Для будущих событий достаточно добавить колонки "#{event_type}_*" в Setting.
#
# @param item [PoiCategory] категория
# @param event_type [String] ключ события ("osm_import", "create", "update", ...)
# @param payload [Hash] контекст события (например { stats:, initiator_id: })
#
class PoiCategoryNotification < ApplicationNotification
  # deliver_by :database deprecated в Noticed 3 — записи создаются автоматически
  deliver_by :email, mailer: "UserMailer", method: :osm_import_complete, if: :email_enabled?
  deliver_by :action_cable, channel: "UserChannel", stream: :user_stream, message: :to_websocket, if: :notifications_enabled?
  deliver_by :web_push, class: "Noticed::DeliveryMethods::WebPush", if: :push_enabled?

  required_param :item
  required_param :event_type
  required_param :payload

  ALLOWED_EVENT_TYPES = %w[osm_import create update].freeze

  #
  # Текст уведомления (in-app, вебсокет)
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
  # Сообщение для WebSocket-канала (UserChannel)
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
  # Включён ли email-канал для получателя (по его Setting)
  #
  # @param recipient [User, nil] получатель
  # @return [Boolean]
  #
  def email_enabled?(recipient = nil)
    setting_field_enabled?(:email, recipient)
  end

  #
  # Включён ли in-app (action_cable) канал для получателя (по его Setting)
  #
  # @param recipient [User, nil] получатель
  # @return [Boolean]
  #
  def notifications_enabled?(recipient = nil)
    setting_field_enabled?(:notifications, recipient)
  end

  #
  # Включён ли push-канал для получателя (по его Setting)
  #
  # @param recipient [User, nil] получатель
  # @return [Boolean]
  #
  def push_enabled?(recipient = nil)
    setting_field_enabled?(:push, recipient)
  end

  #
  # Персональный стрим получателя
  #
  # @return [String]
  #
  def user_stream
    "user_#{recipient.id}"
  end

  private

  #
  # Заголовок уведомления (в т.ч. для вебсокета)
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
  # Статистика из payload (для события импорта)
  #
  # @return [Hash]
  #
  def stats
    params[:payload].is_a?(Hash) ? params[:payload].fetch(:stats, {}) : {}
  end

  #
  # Проверяет настройку получателя для канала (type) события event_type.
  # Читает поле вида "#{event_type}_#{type}_enabled?" из Setting получателя.
  # Если поля нет (событие без настроек) — возвращает false.
  #
  # @param type [Symbol] :email, :notifications или :push
  # @param recipient [User, nil] получатель (по умолчанию — текущий)
  # @return [Boolean]
  #
  def setting_field_enabled?(type, recipient = nil)
    recipient ||= self.recipient
    return false unless recipient&.setting

    event_type = params[:event_type].to_s
    return false unless ALLOWED_EVENT_TYPES.include?(event_type)

    method_name = "#{event_type}_#{type}_enabled?"
    recipient.setting.respond_to?(method_name) && recipient.setting.public_send(method_name)
  rescue StandardError => e
    Rails.logger.error("PoiCategoryNotification setting check error: #{e.message}")
    false
  end
end
