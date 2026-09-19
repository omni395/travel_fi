# frozen_string_literal: true

#
# PoiCommentBroadcaster — отправляет live-события о новых комментариях через WebSocket.
#
# Ответственность:
# 1. Получает созданный/изменённый комментарий (VersionObserverJob).
# 2. Рендерит ТОЧЕЧНЫЙ инстанс Comments::CommentComponent (одна запись).
# 3. Доставляет его в общий стрим "pois_map" (все, кто открыл карточку POI)
#    через inner_html/insert_adjacent_html в контейнер-цель [data-comments-list].
# 4. Шлёт уведомление автору ветки в user_<id> (+ Noticed отдельно в job).
#
# ТОЧЕЧНОСТЬ (догма): НЕ перерендериваем всё дерево комментариев — это ломает
# форму ввода, скролл и свёрнутые ветки. Добавляем только ноду комментария.
# Только inner_html/insert_adjacent_html, НЕ morph (падение undefined.dispatchEvent).
#
class PoiCommentBroadcaster
  include CableReady::Broadcaster

  #
  # Отправляет live-событие о комментарии.
  #
  # @param comment [PoiComment] комментарий
  # @param event [Symbol] :create / :update / :destroy
  #
  def self.call(comment:, event: :create)
    new(comment: comment, event: event).broadcast
  end

  attr_reader :comment, :event

  def initialize(comment:, event: :create)
    @comment = comment
    @event = event
  end

  #
  # Выполняет broadcast события в общий стрим карты (все зрители карточки POI)
  # и персонально автору ветки/родителю.
  #
  def broadcast
    # 1. Destroy: удаляем ноду комментария у публичных зрителей точечно.
    if event == :destroy
      cable_ready["pois_map"].remove(
        selector: "[data-comment-id='#{comment.id}']"
      )
      cable_ready.broadcast
      Rails.logger.info("PoiCommentBroadcaster: Removed comment ##{comment.id} (POI ##{comment.poi_id})")
      return
    end

    # 1. Общий стрим карты: рендерим инстанс комментария и вставляем в список.
    html = render_comment_component
    if html.present?
      cable_ready["pois_map"].insert_adjacent_html(
        selector: "[data-comments-list='poi-#{comment.poi_id}']",
        position: event == :create ? "beforeend" : "afterbegin",
        html: html
      )
    end

    # 2. Персональный поток автору ветки (родителю) — событие для клиента.
    involved = [ comment.parent&.user_id ].compact.uniq
    involved.each do |user_id|
      next if user_id == comment.user_id

      cable_ready["user_#{user_id}"].dispatch_event(
        name: "poi:comment-reply",
        detail: { poi_id: comment.poi_id, comment_id: comment.id, author: comment.user&.name }
      )
    end

    cable_ready.broadcast

    Rails.logger.info("PoiCommentBroadcaster: Sent #{event} for comment ##{comment.id} (POI ##{comment.poi_id})")
  rescue StandardError => e
    Rails.logger.error("PoiCommentBroadcaster error: #{e.class} #{e.message}")
  end

  private

  #
  # Рендерит точечный инстанс комментария. Верхнеуровневый одиночный рендер
  # через ApplicationController.render допустим (аналог PoiBroadcaster);
  # сбой — пустая строка, broadcast продолжается.
  #
  # @return [String] HTML ноды комментария
  #
  def render_comment_component
    ApplicationController.render(
      Comments::CommentComponent.new(comment: comment),
      layout: false
    )
  rescue StandardError => e
    Rails.logger.error("PoiCommentBroadcaster render failed: #{e.class} #{e.message}")
    ""
  end
end
