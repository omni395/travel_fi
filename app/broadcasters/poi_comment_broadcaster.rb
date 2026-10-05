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
    # Destroy: удаляем ноду комментария у публичных зрителей точечно.
    if event == :destroy
      cable_ready["pois_map"].remove(
        selector: "[data-comment-id='#{comment.id}']"
      )
      cable_ready.broadcast
      Rails.logger.info("PoiCommentBroadcaster: Removed comment ##{comment.id} (POI ##{comment.poi_id})")
      return
    end

    # Скрытие модерацией (hidden_at set, event=:update): публичные зрители не
    # должны видеть скрытый комментарий — удаляем нoду точечно, не рендерим заглушку.
    # Заглушка «скрыт модерацией» показывается автору только при ручном рендере
    # (вне visible scope она не появляется у других).
    if event == :update && comment.hidden?
      cable_ready["pois_map"].remove(
        selector: "[data-comment-id='#{comment.id}']"
      )
      cable_ready.broadcast
      Rails.logger.info("PoiCommentBroadcaster: Hidden comment ##{comment.id} removed (POI ##{comment.poi_id})")
      return
    end

    html = render_comment_component
    if html.present?
      if event == :create
        # Убираем заглушку «нет комментариев» (если висит на отдельном блоке
        # [data-comments-empty]) — иначе она останется рядом с первым комментарием.
        cable_ready["pois_map"].remove(selector: "[data-comments-empty]")

        if comment.parent_id.present?
          # Ответ — вставляем В РОДИТЕЛЯ в его контейнер [data-comment-children]
          # (вложенность вместо top-level дубля). При свёрнутой ветке родителя
          # нода не видна — не вставляем (collapsed отрисует при разворачивании).
          cable_ready["pois_map"].insert_adjacent_html(
            selector: "[data-comment-id='#{comment.parent_id}'] [data-comment-children]",
            position: "beforeend",
            html: html
          )
        else
          # Корневой комментарий — в конец списка корневых [data-comments-list].
          cable_ready["pois_map"].insert_adjacent_html(
            selector: "[data-comments-list='poi-#{comment.poi_id}']",
            position: "beforeend",
            html: html
          )
        end
      else
        # Update (правка текста автором/admin) — ЗАМЕНЯЕМ ТОЛЬКО контент записи
        # через inner_html на [data-comment-content]. Это НЕ пересоздаёт обёртку
        # [data-comment-id] и НЕ трогает [data-comment-children] → нет самовложения
        # и дубля. Полный html обёртки содержит тот же data-comment-id и вставил бы
        # сам себя (вложенность) — поэтому рендерим именно контент-компонент.
        content_html = render_comment_content_component
        if content_html.present?
          cable_ready["pois_map"].inner_html(
            selector: "[data-comment-id='#{comment.id}'] [data-comment-content]",
            html: content_html
          )
          # После live-правки inner_html на [data-comment-content] вставленные заново
          # кнопки автор/редактора/staff остаются скрытыми (Stimulus не пересканирует
          # контент и не зовёт connect повторно). Шлём событие на обёртку
          # [data-comment-id] — контроллер слушает poi:comment-updated и повторно
          # раскрывает персональные кнопки по правам (refreshPermissions).
          cable_ready["pois_map"].dispatch_event(
            name: "poi:comment-updated",
            selector: "[data-comment-id='#{comment.id}']",
            detail: { poi_id: comment.poi_id, comment_id: comment.id }
          )
        end
      end
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

  #
  # Рендерит ТОЛЬКО контент записи (Comments::CommentContentComponent) для
  # точечного inner_html при :update (правка тела). В отличие от полной обёртки
  # CommentComponent, этот HTML не содержит data-comment-id/data-comment-children,
  # поэтому inner_html на [data-comment-content] меняет только текст/действия,
  # НЕ создавая самовложения и НЕ дублируя ответы.
  #
  # @return [String] HTML контента комментария
  #
  def render_comment_content_component
    ApplicationController.render(
      Comments::CommentContentComponent.new(comment: comment),
      layout: false
    )
  rescue StandardError => e
    Rails.logger.error("PoiCommentBroadcaster content render failed: #{e.class} #{e.message}")
    ""
  end
end
