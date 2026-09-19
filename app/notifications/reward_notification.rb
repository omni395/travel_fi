# frozen_string_literal: true

#
# RewardNotification — уведомление о начислении токенов TFT пользователю.
#
# Два под-события (параметр event_type):
#   - "reward_available" — токены разблокированы по лок-периоду, можно забрать (claim)
#   - "reward_locked"    — токены начислены, но ещё заблокированы лок-периодом
#
# Каналы фильтруются по личным настройкам получателя (Setting) через
# SettingFilterable с ключом события из event_type:
#   канал = мастер-флаг (notifications/email/push_enabled) AND
#           reward_available_<channel>_enabled / reward_locked_<channel>_enabled
#
# @param amount [Numeric] количество токенов TFT
# @param action_key [String] ключ начисления (poi_create, comment_create, ...)
# @param event_type [String] "reward_available" | "reward_locked"
# @param token_transaction [TokenTransaction, nil] журнал движения токенов
#
class RewardNotification < ApplicationNotification
  include SettingFilterable

  ALLOWED_EVENT_TYPES = %w[reward_available reward_locked].freeze

  required_param :amount
  required_param :action_key
  required_param :event_type
  required_param :token_transaction, default: nil

  # deliver_by :database deprecated в Noticed 3 — записи создаются автоматически
  deliver_by :email, mailer: "UserMailer", method: :profile_updated, if: :email_enabled?
  deliver_by :action_cable, channel: "UserChannel", stream: :user_stream, message: :to_websocket, if: :notifications_enabled?
  deliver_by :web_push, class: "Noticed::DeliveryMethods::WebPush", if: :push_enabled?

  #
  # Текст уведомления (in-app, вебсокет).
  #
  # @return [String]
  #
  def message
    I18n.t("notifications.rewards.#{event_type}", amount: params[:amount].to_s)
  end

  #
  # Сообщение для WebSocket-канала (UserChannel).
  #
  # @return [Hash]
  #
  def to_websocket
    {
      title: I18n.t("notifications.rewards.title"),
      message: message,
      amount: params[:amount].to_s,
      action_key: params[:action_key],
      event_type: event_type
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
  # Нормализует event_type.
  #
  # @return [String]
  #
  def event_type
    params[:event_type].to_s
  end

  #
  # Ключ события для фильтрации настройки определяется из event_type
  # ("reward_available" или "reward_locked") в рантайме.
  #
  # @return [String]
  #
  def event_setting_key
    event_type
  end
end
