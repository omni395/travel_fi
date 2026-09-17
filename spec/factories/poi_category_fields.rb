# frozen_string_literal: true

#
# Фабрика PoiCategoryField — динамическое поле категории POI.
# label — JSONB с переводами, field_type из валидного набора.
#
FactoryBot.define do
  factory :poi_category_field do
    poi_category
    sequence(:field_key) { |n| "field_#{n}" }
    field_type { "string" }
    active { true }
    required { false }
    position { 0 }
    label do
      {
        "en" => "Field",
        "ru" => "Поле",
        "es" => "Campo",
        "zh" => "字段"
      }
    end
    placeholder { {} }
    hint { nil }
    options { {} }

    trait :boolean_field do
      field_type { "boolean" }
    end

    trait :select_field do
      field_type { "select" }
      options do
        [
          { "value" => "a", "label" => { "en" => "A", "ru" => "А" } },
          { "value" => "b", "label" => { "en" => "B", "ru" => "Б" } }
        ]
      end
    end

    trait :required do
      required { true }
    end

    trait :with_osm_mapping do
      field_type { "boolean" }
      osm_keys { [ "wheelchair" ] }
      osm_value_map { { "yes" => true, "no" => false } }
      osm_transform { "boolean" }
    end
  end
end
