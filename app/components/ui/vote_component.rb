# frozen_string_literal: true

#
# Ui::VoteComponent — блок голосования сообщества (Community Moderation).
#
# Отображает:
#   - Кнопки «Апрув» (+1, MDI mdi-thumb-up-outline) и «Дизлайк» (-1,
#     MDI mdi-thumb-down-outline) с активным состоянием текущего юзера.
#   - Счётчик голосов (ups / downs).
#   - Общее количество голосов.
#
# Live-обновление — через VoteBroadcaster (inner_html [data-vote-…]).
# Интерактивность — через Ui::VoteComponent Stimulus-контроллер → VoteReflex.
#
# @param votable [Poi, Photo, PoiComment] голосуемая сущность
# @param current_user [User, nil] текущий пользователь (активное состояние)
#
class Ui::VoteComponent < ApplicationComponent
  def initialize(votable:, current_user: nil)
    @votable = votable
    @current_user = current_user
  end

  private

  attr_reader :votable, :current_user

  delegate :id, to: :votable, prefix: :votable

  #
  # Число голосов «Апрув» (+1) сущности.
  #
  # @return [Integer]
  #
  def ups
    tally[:ups] || 0
  end

  #
  # Число голосов «Дизлайк» (-1) сущности.
  #
  # @return [Integer]
  #
  def downs
    tally[:downs] || 0
  end

  #
  # Суммарное число голосов (ups + downs).
  #
  # @return [Integer]
  #
  def total
    tally[:total] || 0
  end

  #
  # Чистая разница голосов (ups - downs).
  #
  # @return [Integer]
  #
  def net
    tally[:net] || 0
  end

  #
  # Псевдоним класса сущности (для data-селектора [data-vote-poi-<id>]).
  #
  # @return [String] "poi" / "photo" / "poi_comment"
  #
  def votable_key
    votable.class.name.underscore
  end

  #
  # Счёт голосов сущности.
  #
  # @return [Hash] { ups:, downs:, total:, net: }
  #
  def tally
    @tally ||= begin
      result = VoteService.tally(votable) if defined?(VoteService)
      result.is_a?(Hash) ? result : { ups: 0, downs: 0, total: 0, net: 0 }
    end
  end

  #
  # Значение текущего голоса текущего пользователя за сущность (1/-1/nil).
  # Используется фронтендом для решения create/destroy/change.
  #
  # @return [Integer, nil]
  #
  def current_vote_value
    return nil unless current_user
    return nil unless votable.respond_to?(:votes)

    votable.votes.where(user: current_user).pick(:value)
  end

  #
  # Голосовал ли текущий пользователь за сущность (апрув?).
  #
  # @return [Boolean]
  #
  def user_voted_up?
    return false unless current_user
    return false unless votable.respond_to?(:votes)

    votable.votes.exists?(user: current_user, value: 1)
  end

  #
  # Голосовал ли текущий пользователь за сущность (дизлайк?).
  #
  # @return [Boolean]
  #
  def user_voted_down?
    return false unless current_user
    return false unless votable.respond_to?(:votes)

    votable.votes.exists?(user: current_user, value: -1)
  end

  #
  # Может ли текущий пользователь голосовать (не автор).
  #
  # @return [Boolean]
  #
  def can_vote?
    return true unless current_user
    return true unless votable.respond_to?(:user_id)

    votable.user_id != current_user.id
  end
end
