# frozen_string_literal: true

#
# PoiCommentNotification — уведомление о новом комментарии/ответе.
#
# Доставляется автору родительского комментария (и опционально автору ветки),
# когда на его комментарий ответили. Каналы фильтруются по личным настройкам
# получателя (Setting) через SettingFilterable с ключом события "my_poi_comment":
#   канал = мастер-флаг (notifications/email/push_enabled) AND
#           my_poi_comment_<channel>_enabled
#
# @param poi [Poi] точка
# @param comment [PoiComment] созданный ответ
# @param reply_author_id [Integer] автор ответа
#
class PoiCommentNotification < ApplicationNotification
  include SettingFilterable
  self.setting_event_key = "my_poi_comment"

  # deliver_by :database deprecated в Noticed 3 — записи создаются автоматически
  deliver_by :email, mailer: "UserMailer", method: :profile_updated, if: :email_enabled?
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
  # Персональный стрим получателя.
  #
  # @return [String]
  #
  def user_stream
    "user_#{recipient.id}"
  end
end
