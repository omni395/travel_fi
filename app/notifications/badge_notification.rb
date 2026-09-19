# frozen_string_literal: true

#
# BadgeNotification — уведомление о получении ачивки (бейджа).
#
# Каналы фильтруются по личным настройкам получателя (Setting) через
# SettingFilterable с ключом события "badge_earned":
#   канал = мастер-флаг (notifications/email/push_enabled) AND
#           badge_earned_<channel>_enabled
#
# @param badge_id [Integer] ID бейджа (см. Setting.gamification_config badges)
# @param badge_key [String] ключ бейджа (registration_complete, first_poi, ...)
#
class BadgeNotification < ApplicationNotification
  include SettingFilterable
  self.setting_event_key = "badge_earned"

  # deliver_by :database deprecated в Noticed 3 — записи создаются автоматически
  deliver_by :email, mailer: "UserMailer", method: :profile_updated, if: :email_enabled?
  deliver_by :action_cable, channel: "UserChannel", stream: :user_stream, message: :to_websocket, if: :notifications_enabled?
  deliver_by :web_push, class: "Noticed::DeliveryMethods::WebPush", if: :push_enabled?

  required_param :badge_id
  required_param :badge_key

  #
  # Текст уведомления (in-app, вебсокет).
  #
  # @return [String]
  #
  def message
    I18n.t("notifications.badge_earned", badge: badge_title)
  end

  #
  # Сообщение для WebSocket-канала (UserChannel).
  #
  # @return [Hash]
  #
  def to_websocket
    {
      title: I18n.t("notifications.badge_earned_title"),
      message: message,
      badge_id: params[:badge_id],
      badge_key: params[:badge_key]
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
  # Локализованное название бейджа.
  #
  # @return [String]
  #
  def badge_title
    I18n.t("gamification.badges.#{params[:badge_key]}.title", default: params[:badge_key].to_s.humanize)
  end
end
