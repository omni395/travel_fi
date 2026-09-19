# frozen_string_literal: true

#
# Comments::CommentListComponent — контейнер списка корневых комментариев.
#
# Используется как ЦЕЛЬ точечного broadcast (CommentBroadcaster): обёртка, в
# которую CommentBroadcaster вставляет новый комментарий через inner_html/
# insert_adjacent_html — НЕ перерендер всего дерева (не ломает форму ввода,
# скролл, свёрнутые ветки).
#
# Контейнер-цель data-comments-list размещается отдельно от корня дерева
# (догма: selector target на обёртке, а не на компоненте).
#
# @param comments [ActiveRecord::Relation<PoiComment>] корневые комментарии
# @param current_user [User, nil] текущий пользователь
# @param moderation [Boolean] режим админ-модерации
# @param sort [Symbol] сортировка ветки
# @param user_lat [Float, nil] широта
# @param user_lng [Float, nil] долгота
#
class Comments::CommentListComponent < ApplicationComponent
  attr_reader :comments, :current_user, :moderation, :sort, :user_lat, :user_lng

  def initialize(comments:, current_user: nil, moderation: false, sort: :new, user_lat: nil, user_lng: nil)
    @comments = comments
    @current_user = current_user
    @moderation = moderation
    @sort = sort
    @user_lat = user_lat
    @user_lng = user_lng
  end

  private

  #
  # Имя контроллера компонента.
  #
  # @return [String]
  #
  def controller_name
    "comments--comment-list-component"
  end
end
