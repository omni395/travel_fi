# frozen_string_literal: true

#
# Admin::CommentAdminBroadcaster — live-обновление таблицы модерации комментариев
# в админ-панели через WebSocket (AdminChannel → admin_feed).
#
# Ответственность:
#   1. Получает изменённый комментарий (VersionObserverJob → handle_poi_comment_update).
#   2. Рендерит актуальную таблицу Admin::Comments::TableComponent.
#   3. Доставляет inner_html в контейнер-цель [data-admin-comments-list].
#
# ТОЧЕЧНОСТЬ (догма): только inner_html (НЕ morph) в обёртку-контейнер, которая
# задаётся в шаблоне страницы, а не на корне компонента. Для pagy добавлен mock
# request (в SolidQueue-воркере нет request → NameError).
#
class Admin::CommentAdminBroadcaster
  include CableReady::Broadcaster

  #
  # Отправляет обновление админ-таблицы комментариев.
  #
  # @param comment [PoiComment] изменённый/созданный/удалённый комментарий
  # @param event [Symbol] :create / :update / :destroy
  #
  def self.call(comment:, event: :update)
    new(comment: comment, event: event).broadcast
  end

  attr_reader :comment, :event

  def initialize(comment:, event: :update)
    @comment = comment
    @event = event
  end

  #
  # Рендерит актуальную таблицу и отправляет inner_html в admin_feed.
  #
  def broadcast
    return unless comment

    comments = PoiComment.order(created_at: :desc).limit(20)
    table_html = render_table(comments)

    return if table_html.blank?

    cable_ready["admin_feed"].inner_html(
      selector: "[data-admin-comments-list]",
      html: table_html
    )
    cable_ready.broadcast

    Rails.logger.info("Admin::CommentAdminBroadcaster: broadcast #{event} for comment ##{comment.id}")
  rescue StandardError => e
    Rails.logger.error("Admin::CommentAdminBroadcaster error: #{e.class} #{e.message}")
  end

  private

  #
  # Рендерит таблицу комментариев. Верхнеуровневый одиночный рендер через
  # ApplicationController.render допустим (аналог Admin::UserBroadcaster).
  # Вложенные компоненты рендерятся через <%= render %> внутри TableComponent.
  #
  # @param comments [ActiveRecord::Relation] комментарии
  # @return [String] HTML таблицы
  #
  def render_table(comments)
    ApplicationController.render(
      Admin::Comments::TableComponent.new(comments: comments, pagy: nil),
      layout: false
    )
  rescue StandardError => e
    Rails.logger.error("Admin::CommentAdminBroadcaster render failed: #{e.class} #{e.message}")
    ""
  end

  #
  # Mock request для Pagy внутри TableComponent (в worker нет request).
  #
  # @return [ActionDispatch::Request]
  #
  def request
    @request ||= ActionDispatch::Request.new({})
  end
end
