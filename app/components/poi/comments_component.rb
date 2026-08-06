# frozen_string_literal: true

#
# Poi::CommentsComponent — таб «Комментарии» карточки POI
#
# ЗАГЛУШКА. Полноценная реализация вынесена в ROADMAP:
#   - создание через PoiReflex#create_comment + proximity-check (антифрод)
#   - live-обновление списка для всех через Broadcaster (VersionObserverJob → PoiCommentsChannel)
#   - рассмотреть объединение с голосованием (RatingsComponent)
#
# @param poi          [Poi] объект POI
# @param current_user [User, nil] текущий пользователь
#
class Poi::CommentsComponent < ApplicationComponent
  attr_reader :poi, :current_user

  def initialize(poi:, current_user: nil)
    @poi = poi
    @current_user = current_user
  end

  private

  attr_reader :poi, :current_user
end
