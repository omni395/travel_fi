# frozen_string_literal: true

#
# Уведомление об изменении профиля пользователя
#
class UserProfileNotification < ApplicationNotification
  # deliver_by :database deprecated в Noticed 3 — записи создаются автоматически
  deliver_by :email, mailer: "UserMailer", method: :profile_updated, if: :email_enabled?
  deliver_by :action_cable, channel: "UserChannel", stream: :user_stream, message: :to_websocket, if: :notifications_enabled?
  deliver_by :web_push, class: "Noticed::DeliveryMethods::WebPush", if: :push_enabled?

  required_param :item
  required_param :event_type

  ALLOWED_EVENT_TYPES = %w[profile_update update].freeze

  def message
    I18n.t("notifications.user_updated", name: params[:item].name)
  end

  def to_websocket
    {
      title: I18n.t("notifications.user_updated_title"),
      message: message,
      item_id: params[:item].id,
      event_type: params[:event_type]
    }
  end

  def email_enabled?(recipient = nil)
    setting_field_enabled?(:email, recipient)
  end

  def notifications_enabled?(recipient = nil)
    setting_field_enabled?(:notifications, recipient)
  end

  def push_enabled?(recipient = nil)
    setting_field_enabled?(:push, recipient)
  end

  def user_stream
    "user_#{recipient.id}"
  end

  private

  def setting_field_enabled?(type, recipient = nil)
    recipient ||= self.recipient
    return false unless recipient&.setting

    evt_type = event_type.to_s
    return false unless ALLOWED_EVENT_TYPES.include?(evt_type)

    method_name = "#{evt_type}_#{type}_enabled?"
    recipient.setting.respond_to?(method_name) && recipient.setting.public_send(method_name)
  rescue StandardError => e
    Rails.logger.error("Notification setting check error: #{e.message}")
    false
  end

  def event_type
    params[:event_type]
  end
end
