# frozen_string_literal: true

#
# PoiCommentNotification — уведомление о новом комментарии/ответе.
#
# Доставляется автору родительского комментария (и опционально автору ветки),
# когда на его комментарий ответили. Каналы фильтруются по личным настройкам
# получателя (Setting) с безопасным fallback:
#   - отдельные колонки события (comment_reply_*) пока НЕ добавлены в Setting,
#     поэтому используем общие комментарий-каналы; при отсутствии колонки
#     уведомление НЕ падает (setting_field_enabled? возвращает false).
#
# @param poi [Poi] точка
# @param comment [PoiComment] созданный ответ
# @param reply_author_id [Integer] автор ответа
#
class PoiCommentNotification < ApplicationNotification
  # deliver_by :database deprecated в Noticed 3 — записи создаются автоматически
  deliver_by :action_cable, channel: "UserChannel", stream: :user_stream, message: :to_websocket, if: :notifications_enabled?
  deliver_by :web_push, class: "Noticed::DeliveryMethods::WebPush", if: :push_enabled?

  required_param :poi
  required_param :comment
  required_param :reply_author_id

  #
  # Текст уведомления (in-app, вебсокет).
  #
  # @return [String]
  #
  def message
    author = params[:poi].user
    name = params[:reply_author_id] ? User.find_by(id: params[:reply_author_id])&.name : nil
    poi_name = params[:poi].respond_to?(:localized_name) ? params[:poi].localized_name : params[:poi].name.to_s

    if name.present?
      I18n.t("notifications.poi_comment_reply", name: name, poi: poi_name)
    else
      I18n.t("notifications.poi_comment_new", poi: poi_name)
    end
  rescue StandardError
    I18n.t("notifications.poi_comment_new", poi: params[:poi].id.to_s)
  end

  #
  # Сообщение для WebSocket-канала (UserChannel).
  #
  # @return [Hash]
  #
  def to_websocket
    {
      title: I18n.t("notifications.poi_comment_reply_title"),
      message: message,
      item_id: params[:comment].id,
      item_type: "PoiComment",
      poi_id: params[:poi].id
    }
  end

  #
  # Включён ли in-app (action_cable) канал для получателя (по его Setting).
  #
  # @param recipient [User, nil] получатель
  # @return [Boolean]
  #
  def notifications_enabled?(recipient = nil)
    setting_field_enabled?(:notifications, recipient)
  end

  #
  # Включён ли push-канал для получателя (по его Setting).
  #
  # @param recipient [User, nil] получатель
  # @return [Boolean]
  #
  def push_enabled?(recipient = nil)
    setting_field_enabled?(:push, recipient)
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
  # Проверка соответствующего поля настройки. Безопасно: метод может
  # отсутствовать (нет колонок comment_* в Setting) — возвращаем дефолт
  # (true), чтобы уведомление не потерялось.
  #
  # @param type [Symbol] :notifications / :push / :email
  # @param recipient [User, nil]
  # @return [Boolean]
  #
  def setting_field_enabled?(type, recipient = nil)
    recipient ||= self.recipient
    return true unless recipient&.setting

    # Общий флаг включения уведомлений юзера (если есть).
    method_name = "notifications_enabled"
    value = if recipient.setting.respond_to?(method_name)
              recipient.setting.public_send(method_name)
    else
              true
    end

    # Для push/email дополнительно проверяем общий флаг канала, если он есть.
    if type == :push && recipient.setting.respond_to?(:push_enabled)
      value = value && recipient.setting.push_enabled
    elsif type == :email && recipient.setting.respond_to?(:email_enabled)
      value = value && recipient.setting.email_enabled
    end

    value
  rescue StandardError => e
    Rails.logger.error("PoiCommentNotification setting check error: #{e.message}")
    true
  end
end
