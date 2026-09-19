# frozen_string_literal: true

#
# Comments::CommentsComponent — универсальная обёртка-дерево комментариев.
#
# Отображает:
#   - форму создания корневого комментария (Comments::CommentFormComponent);
#   - список корневых комментариев (Comments::CommentComponent с детьми);
#   - переключатель сортировки best/new (Stimulus → PoiReflex#sort_comments).
#
# Универсальный полиморфный контракт: `commentable` — любая сущность, у которой
# есть ассоциация `poi_comments` (сейчас Poi). Режим `moderation: true` включает
# админ-кнопки (скрыть/удалить), используемый в админ-табе POI.
#
# Live-обновление — через CommentBroadcaster (точечный inner_html/insert_adjacent),
# а НЕ перерендер всей обёртки (не ломает форму ввода/скролл/сортировку).
#
# @param commentable [Poi] владелец комментариев
# @param current_user [User, nil] текущий пользователь
# @param sort [Symbol] :new / :best
# @param moderation [Boolean] режим админ-модерации
# @param user_lat [Float, nil] широта юзера (для proximity-проверки создания)
# @param user_lng [Float, nil] долгота юзера
#
class Comments::CommentsComponent < ApplicationComponent
  attr_reader :commentable, :current_user, :sort, :moderation, :user_lat, :user_lng

  def initialize(commentable:, current_user: nil, sort: :new, moderation: false, user_lat: nil, user_lng: nil)
    @commentable = commentable
    @current_user = current_user
    @sort = sort
    @moderation = moderation
    @user_lat = user_lat
    @user_lng = user_lng
  end

  private

  #
  # Корневые комментарии с выбранным упорядочиванием (из CommentService).
  #
  # @return [ActiveRecord::Relation<PoiComment>]
  #
  def root_comments
    @root_comments ||= CommentService.roots(commentable, sort: sort)
  end

  #
  # Имя контроллера для корневой обёртки (кebab case).
  #
  # @return [String]
  #
  def controller_name
    "comments--comments-component"
  end

  #
  # Может ли пользователь создавать комментарий (залогинен + admin/mod исключения).
  # Финальная проверка — в PoiCommentPolicy; здесь — только видимость формы.
  #
  # @return [Boolean]
  #
  def can_comment?
    return false if current_user.nil?

    current_user.has_role?(:admin) || current_user.has_role?(:moderator) || proximity_ok?
  end

  #
  # Доступен ли proximity (100м) — грубая проверка перед показом формы.
  #
  # @return [Boolean]
  #
  def proximity_ok?
    user_lat.present? && user_lng.present? && commentable.respond_to?(:latitude)
  end

  #
  # Локализованный placeholder поля ввода (определяется контекстом владельца).
  #
  # @return [String]
  #
  def write_placeholder
    if commentable.respond_to?(:localized_name) && commentable.localized_name.present?
      t(".write_placeholder", name: commentable.localized_name)
    else
      t(".write_placeholder_generic")
    end
  end
end
