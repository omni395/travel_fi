# frozen_string_literal: true

#
# VotePolicy — политика доступа к голосам сообщества.
#
# Правила:
# - Только залогиненный пользователь может голосовать (create).
# - Автор НЕ может голосовать за своё (не голосуем за себя).
# - Голосовать можно ТОЛЬКО за видимую точку (approved/imported); pending — нет.
#
# Проксимити 100м (анти-фрод) проверяется в Reflex через check_proximity! —
# там доступна сессия с координатами юзера (в Pundit policy сессии нет).
#
class VotePolicy < ApplicationPolicy
  #
  # Может ли пользователь голосовать за сущность.
  #
  # @return [Boolean]
  #
  def create?
    return false unless user
    return false if record.is_a?(Poi) && !(record.approved? || record.imported?)

    # Автор не голосует за своё.
    !authored_by?(record, user)
  end

  private

  #
  # Является ли пользователь автором сущности.
  #
  # @param votable [Poi, Photo, PoiComment] сущность
  # @param user [User] пользователь
  # @return [Boolean]
  #
  def authored_by?(votable, user)
    votable_user_id = votable.respond_to?(:user_id) ? votable.user_id : nil
    votable_user_id.present? && votable_user_id == user.id
  end
end
