# frozen_string_literal: true

#
# Фабрика PoiComment — комментарий к POI.
# Поддерживает thread через parent (self-join).
#
FactoryBot.define do
  factory :poi_comment do
    poi
    user
    body { "Test comment" }

    trait :reply do
      association :parent, factory: :poi_comment
    end
  end
end
