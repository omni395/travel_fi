# frozen_string_literal: true

#
# Ui::VoteComponent — блок голосования сообщества (Community Moderation).
#
# Отображает:
#   - Кнопки «Апрув» (+1, MDI mdi-thumb-up-outline) и «Дизлайк» (-1,
#     MDI mdi-thumb-down-outline) с активным состоянием текущего юзера.
#   - Счётчик голосов (ups / downs).
#   - Бейдж «Одобрено сообществом» / «Отклонено сообществом» (для POI).
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
    @tally ||= VoteService.tally(votable)
  end

  #
  # Значение текущего голоса текущего пользователя за сущность (1/-1/nil).
  # Используется фронтендом для решения create/destroy/change.
  #
  # @return [Integer, nil]
  #
  def current_vote_value
    return nil unless current_user

    votable.votes.where(user: current_user).pick(:value)
  end

  #
  # Голосовал ли текущий пользователь за сущность (апрув?).
  #
  # @return [Boolean]
  #
  def user_voted_up?
    return false unless current_user

    votable.votes.exists?(user: current_user, value: 1)
  end

  #
  # Голосовал ли текущий пользователь за сущность (дизлайк?).
  #
  # @return [Boolean]
  #
  def user_voted_down?
    return false unless current_user

    votable.votes.exists?(user: current_user, value: -1)
  end

  #
  # Может ли текущий пользователь голосовать (не автор).
  #
  # Кнопка блокируется ТОЛЬКО если залогиненный юзер является автором сущности.
  # Гость и worker-контекст (current_user == nil при рендере из SolidQueue через
  # VoteBroadcaster) НЕ получают disabled: иначе после первого live-обновления
  # кнопки голосования стали бы disabled у всех — «не срабатывают». Правовую
  # защиту (гость/автор/проксимити) обеспечивает VotePolicy на бэке.
  #
  # @return [Boolean]
  #
  def can_vote?
    return true unless current_user

    votable.user_id != current_user.id
  end

  #
  # Для POI: одобрена ли точка сообществом (бейдж «Одобрено сообществом»).
  #
  # @return [Boolean]
  #
  def community_approved?
    votable.is_a?(Poi) && votable.community_approved?
  end

  #
  # Для POI: отклонена ли точка сообществом (бейдж «Отклонено сообществом»).
  #
  # @return [Boolean]
  #
  def community_rejected?
    votable.is_a?(Poi) && votable.community_rejected?
  end
end
