# frozen_string_literal: true

#
# PoiStatusNotification — уведомление об изменении статуса собственной точки
# пользователя (одобрена админом/сообществом, отклонена, изменена).
#
# Каналы фильтруются по личным настройкам получателя (Setting) через
# SettingFilterable с ключом события "my_poi_status":
#   канал = мастер-флаг (notifications/email/push_enabled) AND
#           my_poi_status_<channel>_enabled
#
# @param poi [Poi] точка
# @param event_type [String] ключ события ("approved" / "rejected" / "updated")
#
class PoiStatusNotification < ApplicationNotification
  include SettingFilterable
  self.setting_event_key = "my_poi_status"

  # deliver_by :database deprecated в Noticed 3 — записи создаются автоматически
  deliver_by :email, mailer: "UserMailer", method: :profile_updated, if: :email_enabled?
  deliver_by :action_cable, channel: "UserChannel", stream: :user_stream, message: :to_websocket, if: :notifications_enabled?
  deliver_by :web_push, class: "Noticed::DeliveryMethods::WebPush", if: :push_enabled?

  required_param :poi
  required_param :event_type

  #
  # Текст уведомления (in-app, вебсокет).
  #
  # @return [String]
  #
  def message
    poi_name = params[:poi].respond_to?(:localized_name) ? params[:poi].localized_name : params[:poi].name.to_s
    I18n.t("notifications.poi_status.#{params[:event_type]}", name: poi_name)
  end

  #
  # Сообщение для WebSocket-канала (UserChannel).
  #
  # @return [Hash]
  #
  def to_websocket
    {
      title: I18n.t("notifications.poi_status_title"),
      message: message,
      item_id: params[:poi].id,
      item_type: "Poi",
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
end
