# frozen_string_literal: true

#
# Admin::CommentsController — модерация комментариев POI в админ-панели.
#
#   index  — список комментариев с фильтрацией (Ransack) и пагинацией (pagy);
#   show   — детальная страница комментария (текст, связка, аудит);
#   hide   — скрыть комментарий (CommentModerationService.hide!);
#   unhide — показать (CommentModerationService.unhide!).
#
class Admin::CommentsController < Admin::BaseController
  PER_PAGE = 20

  # Pundit: policy_scope не нужен (используем PoiComment напрямую, политика
  # только проверяет права на ресурс).
  skip_after_action :verify_policy_scoped, only: %i[index show]

  #
  # Список комментариев с фильтрацией (body_cont, по POI/автору, hidden_eq)
  # и пагинацией.
  #
  def index
    authorize PoiComment, :index?

    @q = PoiComment.ransack(params[:q])
    comments = @q.result.order(created_at: :desc)
    @pagy, @comments = pagy(comments, limit: PER_PAGE)
  end

  #
  # Детальная страница комментария: текст, автор, связка (родитель/дети),
  # аудит (версии) и кнопки модерации.
  #
  def show
    @comment = PoiComment.includes(:user, :poi, :parent, :children).find(params[:id])
    authorize @comment, :show?

    @versions = @comment.versions.order(created_at: :desc)
  end

  #
  # Скрывает комментарий (PATCH /admin-panel/comments/:id/hide).
  #
  def hide
    @comment = PoiComment.find(params[:id])
    authorize @comment, :hide?
    CommentModerationService.hide!(comment: @comment)

    redirect_back(fallback_location: admin_comment_path(id: @comment), notice: t("admin.comments.hide_success"))
  rescue Pundit::NotAuthorizedError
    redirect_back(fallback_location: admin_comments_path, alert: t("admin.access_denied"))
  end

  #
  # Показывает ранее скрытый комментарий (PATCH /:id/unhide).
  #
  def unhide
    @comment = PoiComment.find(params[:id])
    authorize @comment, :unhide?
    CommentModerationService.unhide!(comment: @comment)

    redirect_back(fallback_location: admin_comment_path(id: @comment), notice: t("admin.comments.unhide_success"))
  rescue Pundit::NotAuthorizedError
    redirect_back(fallback_location: admin_comments_path, alert: t("admin.access_denied"))
  end
end
