# frozen_string_literal: true

#
# Фабрика Poi — точка интереса.
# coordinates — PostGIS point через RGeo spherical_factory (srid 4326).
#
FactoryBot.define do
  factory :poi do
    user
    poi_category
    sequence(:slug) { |n| "poi-#{n}" }
    name do
      {
        "en" => "Test POI",
        "ru" => "Тестовая точка",
        "es" => "Punto de prueba",
        "zh" => "测试点"
      }
    end
    description do
      {
        "en" => "Description",
        "ru" => "Описание",
        "es" => "Descripción",
        "zh" => "描述"
      }
    end
    coordinates { PoiService.parse_coordinates(50.4501, 30.5234) }
    status { :approved }
    source { :manual }
    metadata { {} }
    opening_hours { {} }
    rating { 0.0 }
    verification_count { 0 }
    wheelchair_accessible { false }

    trait :pending do
      status { :pending }
    end

    trait :rejected do
      status { :rejected }
    end

    trait :archived do
      status { :archived }
    end

    trait :from_osm do
      source { :osm }
      sequence(:osm_id) { |n| n }
    end

    trait :verified do
      verification_count { 5 }
      last_verified_at { Time.current }
    end
  end
end
