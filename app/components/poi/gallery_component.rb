# frozen_string_literal: true

#
# Poi::GalleryComponent — таб «Галерея» карточки POI
#
# ЗАГЛУШКА. Данные галереи (Poi#photos + PhotoService) уже готовы,
# полноценный просмотр (сетка миниатюр + lightbox/слайдер) вынесен в ROADMAP.
#
# @param poi [Poi] объект POI
#
class Poi::GalleryComponent < ApplicationComponent
  attr_reader :poi

  def initialize(poi:)
    @poi = poi
  end

  private

  attr_reader :poi
end
