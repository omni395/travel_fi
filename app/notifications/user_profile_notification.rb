# frozen_string_literal: true

#
# Уведомление об изменении профиля пользователя
#
class UserProfileNotification < ApplicationNotification
  deliver_by :database
  deliver_by :email, mailer: "UserMailer", method: :profile_updated, if: :email_enabled?
  deliver_by :action_cable, channel: "UserChannel", stream: :user_stream, message: :to_websocket, if: :notifications_enabled?
  deliver_by :web_push, class: "Noticed::DeliveryMethods::WebPush", if: :push_enabled?

  param :item
  param :event_type

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

    method_name = "#{event_type}_#{type}_enabled?"

    recipient.setting.respond_to?(method_name) && recipient.setting.send(method_name)
  rescue StandardError => e
    Rails.logger.error("Notification setting check error: #{e.message}")
    false
  end

  def event_type
    params[:event_type]
  end
end
