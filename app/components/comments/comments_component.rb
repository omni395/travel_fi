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
  # Может ли пользователь создавать комментарий. Только статус active
  # (см. UserAccessService.can_interact?). Админ/модератор — тоже active
  # статусом (роль не отменяет блокировку). Финальная проверка —
  # в PoiCommentPolicy; здесь — только видимость формы.
  #
  # @return [Boolean]
  #
  def can_comment?
    UserAccessService.can_interact?(current_user)
  end

  #
  # Причина, блокирующая создание комментария (сейчас только suspended).
  # Используется для плашки «почему нельзя оставить комментарий» и даты снятия.
  #
  # @return [Hash, nil] { reason: :suspended, unlock_at: Time } или nil
  #
  def interaction_block
    UserAccessService.interaction_block(current_user)
  end

  #
  # Доступен ли proximity (100м) — юзер в радиусе точки. Админ/модератор
  # всегда в радиусе (обходят проверку внутри PoiService.within_range?).
  #
  # @return [Boolean]
  #
  def proximity_ok?
    return false unless user_lat.present? && user_lng.present?
    return false unless commentable.respond_to?(:latitude) && commentable.latitude.present?

    PoiService.within_range?(
      user_lat: user_lat,
      user_lng: user_lng,
      poi_lat: commentable.latitude,
      poi_lng: commentable.longitude,
      user: current_user
    )
  end

  #
  # Юзер active, но вне радиуса 100м — плашка «слишком далеко».
  # Отличается от отсутствия геоданных (no_location не показываем как причину).
  #
  # @return [Boolean]
  #
  def too_far?
    return false unless user_lat.present? && user_lng.present? && can_comment? == false

    interaction_block.nil? && !proximity_ok?
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
