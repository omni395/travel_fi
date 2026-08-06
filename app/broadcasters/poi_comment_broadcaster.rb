# frozen_string_literal: true

#
# PoiCommentBroadcaster — отправляет live-события о новых комментариях через WebSocket.
#
# Ответственность:
# 1. Получает созданный комментарий
# 2. Формирует CableReady-инструкции (dispatch_event в UserChannel автора)
# 3. Отправляет в стрим user_<id> (UserChannel)
#
# NOTE: Полный live для всех подписанных (гео-зоны) — в ROADMAP (2.2).
# Здесь — базовый каркас: автор получает событие, карточка POI может
# перезапросить комментарии.
#
class PoiCommentBroadcaster
  include CableReady::Broadcaster

  #
  # Отправляет событие о создании комментария
  #
  # @param comment [PoiComment] созданный комментарий
  #
  def self.call(comment:)
    new(comment: comment).broadcast
  end

  attr_reader :comment

  def initialize(comment:)
    @comment = comment
  end

  #
  # Выполняет broadcast события
  #
  def broadcast
    cable_ready["user_#{comment.user_id}"].dispatch_event(
      name: "poi:comment-created",
      detail: { poi_id: comment.poi_id, comment_id: comment.id }
    )
    cable_ready["user_#{comment.user_id}"].broadcast

    Rails.logger.info("PoiCommentBroadcaster: Sent comment event for POI ##{comment.poi_id}")
  rescue StandardError => e
    Rails.logger.error("PoiCommentBroadcaster error: #{e.class} #{e.message}")
  end
end
