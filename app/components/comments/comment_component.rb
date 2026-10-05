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
  # Рендерятся в отдельном контейнере [data-comment-children] обёртки.
  #
  # @return [ActiveRecord::Relation<PoiComment>]
  #
  def children
    @children ||= comment.children.visible.order(created_at: :asc)
  end

  #
  # Ответил ли текущий пользователь уже на этот комментарий.
  # Только для корня ветки; UI скрывает кнопку «Ответить» (анти-флуд).
  # Бэкенд-рубеж — CommentService + валидации модели (здесь только UX).
  #
  # @return [Boolean]
  #
  def i_replied?
    return false if current_user.nil?
    return false if comment.parent.present?

    current_user.poi_comments.where(parent_id: comment.id).exists?
  end

  #
  # Свёрнута ли ветка ответов (рендер кнопки «Показать N» вместо детей).
  # Порог — COLLAPSE_THRESHOLD. Кнопка «Показать N» → PoiReflex#expand_replies.
  #
  # @return [Boolean]
  #
  def collapsed?
    comment.children_count.to_i >= COLLAPSE_THRESHOLD
  end

  # Порог сворачивания ветки
  COLLAPSE_THRESHOLD = 4
end
