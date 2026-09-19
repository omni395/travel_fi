# frozen_string_literal: true

#
# Уведомление об изменении профиля/регистрации пользователя.
#
# Доставляется админам (+ инициатору). Каналы фильтруются по личным настройкам
# получателя через SettingFilterable с ключом "profile_updated":
#   канал = мастер-флаг (notifications/email/push_enabled) AND
#           profile_updated_<channel>_enabled
#
class UserProfileNotification < ApplicationNotification
  include SettingFilterable
  self.setting_event_key = "profile_updated"

  # deliver_by :database deprecated в Noticed 3 — записи создаются автоматически
  deliver_by :email, mailer: "UserMailer", method: :profile_updated, if: :email_enabled?
  deliver_by :action_cable, channel: "UserChannel", stream: :user_stream, message: :to_websocket, if: :notifications_enabled?
  deliver_by :web_push, class: "Noticed::DeliveryMethods::WebPush", if: :push_enabled?

  required_param :item
  required_param :event_type

  #
  # Текст уведомления (in-app, вебсокет).
  #
  # @return [String]
  #
  def message
    I18n.t("notifications.user_updated", name: params[:item].name)
  end

  #
  # Сообщение для WebSocket-канала (UserChannel).
  #
  # @return [Hash]
  #
  def to_websocket
    {
      title: I18n.t("notifications.user_updated_title"),
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
end
