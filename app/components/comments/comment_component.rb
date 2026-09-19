# frozen_string_literal: true

#
# Comments::CommentComponent — отдельная запись комментария (корень или ответ).
#
# Отображает:
#   - аватар/имя автора, дату, тело (с пометкой @предка при флоттенинге);
#   - голосование (Ui::VoteComponent → VoteService → VoteBroadcaster);
#   - кнопку «Ответ» (для корня / флоттенед ответ → ответ на корень);
#   - вложенные дети (1 уровень ответов);
#   - кнопку «Показать N ответов» для свёрнутых веток;
#   - кнопки редактирования/удаления (автор/admin) + админ-кнопки в moderation.
#
# Рендер вложенных детей — строго через render (view_context), допустимо из
# SolidQueue worker (догма: НЕ ApplicationController.render внутри компонента).
#
# @param comment [PoiComment] комментарий
# @param current_user [User, nil] текущий пользователь
# @param moderation [Boolean] режим админ-модерации
# @param sort [Symbol] сортировка ветки (пробрасывается в Children)
# @param user_lat [Float, nil] широта юзера
# @param user_lng [Float, nil] долгота юзера
#
class Comments::CommentComponent < ApplicationComponent
  with_collection_parameter :comment

  attr_reader :comment, :current_user, :moderation, :sort, :user_lat, :user_lng

  def initialize(comment:, current_user: nil, moderation: false, sort: :new, user_lat: nil, user_lng: nil)
    @comment = comment
    @current_user = current_user
    @moderation = moderation
    @sort = sort
    @user_lat = user_lat
    @user_lng = user_lng
  end

  private

  #
  # Прямые ответы на комментарий (дети, 1 уровень) — только видимые.
  #
  # @return [ActiveRecord::Relation<PoiComment>]
  #
  def children
    @children ||= comment.children.visible.order(created_at: :asc)
  end

  #
  # Имя контроллера компонента.
  #
  # @return [String]
  #
  def controller_name
    "comments--comment-component"
  end

  #
  # Пометка @предка для флоттенед ответа (ответ на ответ → ответ на корень).
  # Если у комментария задан parent, отличный от корня — это флоттенинг.
  #
  # @return [User, nil]
  #
  def reply_target_name
    return nil if comment.parent.nil?
    return nil if comment.root_id == comment.parent_id

    comment.parent.user.name
  end

  #
  # Может ли текущий пользователь редактировать (автор или admin).
  #
  # @return [Boolean]
  #
  def can_edit?
    return false if current_user.nil?

    current_user.has_role?(:admin) || comment.user_id == current_user.id
  end

  #
  # Может ли текущий пользователь удалять (автор или admin).
  #
  # @return [Boolean]
  #
  def can_destroy?
    can_edit?
  end

  #
  # Показывать ли кнопку «Ответ» (только для корня; ответы уже 1 уровень —
  # отвечаем на корень, чтобы не углублять дерево).
  #
  # @return [Boolean]
  #
  def replyable?
    comment.parent.nil? && current_user.present?
  end

  #
  # Свёрнута ли ветка (много ответов → показываем кнопку «Показать N»).
  #
  # @return [Boolean]
  #
  def collapsed?
    comment.children_count.to_i > COLLAPSE_THRESHOLD
  end

  # Порог сворачивания ветки
  COLLAPSE_THRESHOLD = 4
end
