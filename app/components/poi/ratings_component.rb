# frozen_string_literal: true

#
# Poi::RatingsComponent — таб «Рейтинги/голосования» карточки POI
#
# Показывает текущий readonly-рейтинг (poi.rating) и счётчик подтверждений
# (verification_count), а также полноценное голосование сообщества
# (Ui::VoteComponent → VoteService → VoteReflex → VoteBroadcaster).
#
# @param poi [Poi] объект POI
# @param current_user [User, nil] текущий пользователь (активное состояние голоса)
#
class Poi::RatingsComponent < ApplicationComponent
  attr_reader :poi

  def initialize(poi:, current_user: nil)
    @poi = poi
    @current_user = current_user
  end

  private

  attr_reader :poi, :current_user
end
