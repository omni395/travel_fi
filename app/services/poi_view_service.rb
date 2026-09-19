# frozen_string_literal: true

#
# PoiViewService — фиксация просмотра карточки точки пользователем.
#
# Используется для эмпирических рекомендаций: накапливает историю «какие
# категории точек пользователь просматривает». При повторном просмотре той же
# точки обновляет viewed_at (unique user_id + poi_id), усиливая вес по свежести.
#
# Вызывается из рефлекса показа деталей POI ТОЛЬКО для авторизованных
# пользователей (гости видят лишь диалог входа и карточку не открывают).
#
class PoiViewService
  #
  # Записывает просмотр точки пользователем. Идемпотентно по паре (user, poi).
  #
  # @param user [User] авторизованный пользователь
  # @param poi [Poi] просмотренная точка
  # @return [PoiView, true, nil] свежая запись либо true (обновлён вес)
  # @raise [ActiveRecord::RecordInvalid] при невалидных данных
  #
  def self.record(user:, poi:)
    return nil unless user && poi

    poi_category_id = poi.poi_category_id

    if (view = PoiView.find_by(user: user, poi: poi))
      view.update!(viewed_at: Time.current, poi_category_id: poi_category_id)
      view
    else
      PoiView.create!(
        user: user,
        poi: poi,
        poi_category: poi.poi_category,
        viewed_at: Time.current
      )
    end
  end
end
