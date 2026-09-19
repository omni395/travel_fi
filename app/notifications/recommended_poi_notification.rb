# frozen_string_literal: true

#
# RecommendedPoiNotification — уведомление о рекомендованной точке (эмпирика).
#
# Формируется RecommendedPoiJob на основе интересов пользователя (PoiView).
# Каналы фильтруются по личным настройкам получателя (Setting) через
# SettingFilterable с ключом события "recommendations":
#   канал = мастер-флаг (notifications/email/push_enabled) AND
#           recommendations_<channel>_enabled
#
# @param poi [Poi] рекомендованная точка
# @param score [Float] оценка релевантности (для диагностики)
#
class RecommendedPoiNotification < ApplicationNotification
  include SettingFilterable
  self.setting_event_key = "recommendations"

  # deliver_by :database deprecated в Noticed 3 — записи создаются автоматически
  deliver_by :email, mailer: "UserMailer", method: :profile_updated, if: :email_enabled?
  deliver_by :action_cable, channel: "UserChannel", stream: :user_stream, message: :to_websocket, if: :notifications_enabled?
  deliver_by :web_push, class: "Noticed::DeliveryMethods::WebPush", if: :push_enabled?

  required_param :poi
  required_param :score

  #
  # Текст уведомления (in-app, вебсокет).
  #
  # @return [String]
  #
  def message
    poi_name = params[:poi].respond_to?(:localized_name) ? params[:poi].localized_name : params[:poi].name.to_s
    I18n.t("notifications.recommendation", name: poi_name)
  end

  #
  # Сообщение для WebSocket-канала (UserChannel).
  #
  # @return [Hash]
  #
  def to_websocket
    {
      title: I18n.t("notifications.recommendation_title"),
      message: message,
      item_id: params[:poi].id,
      item_type: "Poi",
      score: params[:score]
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
