# frozen_string_literal: true

#
# Admin::Comments::PoiComment::ShowComponent — детальная страница комментария
# в админке (модерация).
#
# Отображает:
#   - текст и автора;
#   - связку Precedence: родитель (если это ответ) и дети (прямые ответы);
#   - актуальные голоса (ups/downs);
#   - аудит (Ui::AuditEntryComponent по версиям PaperTrail);
#   - кнопки Скрыть/Показать/Удалить (Admin::CommentsReflex).
#
# @param comment [PoiComment]
# @param versions [ActiveRecord::Relation<PaperTrail::Version>] история изменений
# @param current_user [User, nil] текущий пользователь админки
#
class Admin::Comments::PoiComment::ShowComponent < ApplicationComponent
  attr_reader :comment, :versions, :current_user

  #
  # @param comment [PoiComment] комментарий
  # @param current_user [User, nil] текущий пользователь
  # @param versions [ActiveRecord::Relation, Array] записи аудита
  #
  def initialize(comment:, current_user: nil, versions: [])
    @comment = comment
    @current_user = current_user
    @versions = versions
  end

  private

  #
  # Родительский комментарий (если ответ).
  #
  # @return [PoiComment, nil]
  #
  def parent
    comment.parent
  end

  #
  # Прямые ответы (depth от корня) — видимые дети.
  #
  # @return [ActiveRecord::Relation<PoiComment>]
  #
  def children
    comment.children.order(created_at: :asc)
  end

  #
  # Актуальные голоса комментария.
  #
  # @return [Hash] { ups:, downs: }
  #
  def vote_tally
    VoteService.tally(comment)
  end

  #
  # Может ли пользователь скрывать/показывать комментарий.
  #
  # @return [Boolean]
  #
  def can_moderate?
    return false if current_user.nil?

    policy = Admin::CommentPolicy.new(current_user, comment)
    policy.hide? || policy.unhide?
  end

  #
  # Может ли пользователь удалять комментарий.
  #
  # @return [Boolean]
  #
  def can_destroy?
    return false if current_user.nil?

    current_user.has_role?(:admin) || current_user.has_role?(:moderator)
  end
end
