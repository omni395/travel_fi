# frozen_string_literal: true

#
# Admin::CommentsReflex — Reflex модерации комментариев POI в админке.
#
# Read-операции:
#   filter — фильтрация списка (Ransack + pagy) — рендер таблицы через inner_html;
#   sort   — переключение сортировки — рендер таблицы через inner_html.
#
# Изменения состояния (НЕ рендерят DOM селекторами — обновление через
# VersionObserverJob → Admin::CommentAdminBroadcaster):
#   hide    — скрыть комментарий (CommentModerationService.hide! + toast);
#   unhide  — показать (CommentModerationService.unhide! + toast);
#   destroy — удалить (CommentService.destroy_comment + toast).
#
class Admin::CommentsReflex < ApplicationReflex
  PER_PAGE = 20

  #
  # Фильтрация списка комментариев (Ransack + pagy). Read: рендер таблицы
  # через CableReady inner_html в контейнер [data-admin-comments-list].
  #
  # @param params [Hash] { q: {..}, page: Integer }
  #
  def filter(params = {})
    params = deep_symbolize_keys(params) if params.is_a?(Hash)
    authorize PoiComment, :index?

    @q = PoiComment.ransack(params[:q])
    @comments = @q.result.order(created_at: :desc)
    @pagy, @comments = pagy(@comments, limit: PER_PAGE, page: params[:page] || 1)

    html = ApplicationController.render(
      Admin::Comments::TableComponent.new(comments: @comments, pagy: @pagy),
      layout: false
    )
    cable_ready["admin_feed"].inner_html(selector: "[data-admin-comments-list]", html: html)
    cable_ready.broadcast
  end

  #
  # Сортировка списка комментариев (read, через inner_html).
  # Поддерживаются: best (по голосам), new (по дате).
  #
  # @param params [Hash] { sort: String, q: {..} }
  #
  def sort(params = {})
    params = deep_symbolize_keys(params) if params.is_a?(Hash)
    authorize PoiComment, :index?

    sort = params[:sort].to_s == "best" ? :best : :new
    @q = PoiComment.ransack(params[:q])
    base = @q.result

    @comments = if sort == :best
                  base.order(Arel.sql(
                    "COALESCE((SELECT SUM(value) FROM votes WHERE votable_type='PoiComment' AND votable_id=poi_comments.id), 0) DESC, created_at DESC"
                  ))
    else
                  base.order(created_at: :desc)
    end

    @pagy, @comments = pagy(@comments, limit: PER_PAGE, page: params[:page] || 1)

    html = ApplicationController.render(
      Admin::Comments::TableComponent.new(comments: @comments, pagy: @pagy),
      layout: false
    )
    cable_ready["admin_feed"].inner_html(selector: "[data-admin-comments-list]", html: html)
    cable_ready.broadcast
  end

  #
  # Скрывает комментарий (модерация). Изменение состояния — только service+
  # бродкаст; ответ клиенту — тост.
  #
  # @param params [Hash] { comment_id: Integer }
  #
  def hide(params = {})
    params = deep_symbolize_keys(params) if params.is_a?(Hash)
    morph :nothing
    comment = PoiComment.find(params[:comment_id])
    authorize comment, :hide?
    CommentModerationService.hide!(comment: comment)

    cable_ready["admin_#{current_user&.id}"].dispatch_event(
      name: "toast",
      detail: { message: t("admin.comments.hide_success"), variant: "success" }
    )
    cable_ready.broadcast
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("CommentsReflex#hide: comment not found — #{e.message}")
  end

  #
  # Показывает ранее скрытый комментарий. Изменение состояния — service+бродкаст.
  #
  # @param params [Hash] { comment_id: Integer }
  #
  def unhide(params = {})
    params = deep_symbolize_keys(params) if params.is_a?(Hash)
    morph :nothing
    comment = PoiComment.find(params[:comment_id])
    authorize comment, :unhide?
    CommentModerationService.unhide!(comment: comment)

    cable_ready["admin_#{current_user&.id}"].dispatch_event(
      name: "toast",
      detail: { message: t("admin.comments.unhide_success"), variant: "success" }
    )
    cable_ready.broadcast
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("CommentsReflex#unhide: comment not found — #{e.message}")
  end

  #
  # Удаляет комментарий (скрывает модерацией через CommentService.destroy_comment
  # → CommentModerationService.hide!). Ветка ответов сохраняется.
  #
  # Опциональная автопенализация автора: при suspend=true — перевод в статус
  # :suspended на 3 дня (UserService.suspend!) + авто-разблокировка джобом.
  #
  # @param params [Hash] { comment_id: Integer, suspend: Boolean }
  #
  def destroy(params = {})
    params = deep_symbolize_keys(params) if params.is_a?(Hash)
    morph :nothing
    comment = PoiComment.find(params[:comment_id])
    authorize comment, :destroy?

    CommentService.destroy_comment(comment: comment)

    if params[:suspend].to_s == "true"
      UserService.suspend!(user: comment.user)
    end

    cable_ready["admin_#{current_user&.id}"].dispatch_event(
      name: "toast",
      detail: { message: t("admin.comments.destroy_success"), variant: "success" }
    )
    cable_ready.broadcast
  rescue ActiveRecord::RecordNotFound => e
    Rails.logger.error("CommentsReflex#destroy: comment not found — #{e.message}")
  rescue ActiveRecord::RecordInvalid => e
    Rails.logger.error("CommentsReflex#destroy: penalty failed — #{e.message}")
  end
end
