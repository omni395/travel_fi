# frozen_string_literal: true

#
# Фабрика PoiCategory — категория точки интереса.
# name/description — JSONB с переводами, slug — уникальный (FriendlyId).
#
FactoryBot.define do
  factory :poi_category do
    sequence(:slug) { |n| "category-#{n}" }
    name do
      {
        "en" => "Category",
        "ru" => "Категория",
        "es" => "Categoría",
        "zh" => "类别"
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
    active { true }
    position { 0 }
    icon { "mdi-map-marker" }
    osm_tags { [] }
    osm_default_name { {} }

    trait :inactive do
      active { false }
    end

    # Категория, готовая к OSM-импорту (osm_tags + дефолтное имя)
    trait :with_osm_tags do
      osm_tags { [ "amenity=toilets" ] }
      osm_default_name do
        {
          "en" => "Public Toilet",
          "ru" => "Общественный туалет",
          "es" => "Baño público",
          "zh" => "公共厕所"
        }
      end
    end

    trait :with_fields do
      after(:create) do |category|
        create(:poi_category_field, poi_category: category, field_key: "name", position: 0)
        create(:poi_category_field, poi_category: category, field_key: "phone", position: 1)
      end
    end
  end
end
