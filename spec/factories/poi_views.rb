# frozen_string_literal: true

#
# Фабрика PoiView — просмотр карточки POI пользователем (эмпирические рекомендации).
#
FactoryBot.define do
  factory :poi_view do
    user
    poi
    poi_category
    viewed_at { Time.current }
  end
end
