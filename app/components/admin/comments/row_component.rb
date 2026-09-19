# frozen_string_literal: true

#
# Admin::Comments::RowComponent — строка таблицы модерации комментариев.
#
# Отображает одну строку: текст, автор, POI, дата, голоса (ups/downs),
# статус (скрыт/виден) и действия (Скрыть/Показать/Удалить).
# Действия выполняются через Admin::CommentsReflex (morph :nothing) —
# обновление списка приходит бродкастером.
#
# @param comment [PoiComment]
# @param current_user [User] администратор/модератор (для проверки прав действий)
#
class Admin::Comments::RowComponent < ApplicationComponent
  attr_reader :comment, :current_user

  #
  # @param comment [PoiComment] комментарий
  # @param current_user [User, nil] текущий пользователь админки
  #
  def initialize(comment:, current_user: nil)
    @comment = comment
    @current_user = current_user
  end

  private

  #
  # Актуальный подсчёт голосов комментария (ups/downs).
  #
  # @return [Hash] { ups:, downs: }
  #
  def vote_tally
    VoteService.tally(comment)
  end

  #
  # Может ли текущий пользователь скрывать/показывать комментарий.
  #
  # @return [Boolean]
  #
  def can_moderate?
    return false if current_user.nil?

    policy = Admin::CommentPolicy.new(current_user, comment)
    policy.hide? || policy.unhide?
  end

  #
  # Может ли текущий пользователь удалять комментарий.
  #
  # @return [Boolean]
  #
  def can_destroy?
    return false if current_user.nil?

    current_user.has_role?(:admin) || current_user.has_role?(:moderator)
  end
end
