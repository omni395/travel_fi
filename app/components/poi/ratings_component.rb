# frozen_string_literal: true

#
# Poi::RatingsComponent — таб «Рейтинги/голосования» карточки POI
#
# ЗАГЛУШКА: показывается текущий readonly-рейтинг (poi.rating) и счётчик
# подтверждений (verification_count). Полноценные пользовательские голосования
# вынесены в ROADMAP (в т.ч. интеграция с GamificationService / ERC-20).
#
# @param poi [Poi] объект POI
#
class Poi::RatingsComponent < ApplicationComponent
  attr_reader :poi

  def initialize(poi:)
    @poi = poi
  end

  private

  attr_reader :poi
end
