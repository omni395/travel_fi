# frozen_string_literal: true

#
# Фабрика Gamification — баллы и бейджи пользователя.
# event_type: "score" (value = баллы) или "badge" (value = badge_id).
#
FactoryBot.define do
  factory :gamification do
    user
    event_type { "score" }
    value { 10 }
    action_key { "poi_created" }
    log { {} }

    trait :badge do
      event_type { "badge" }
      value { 1 }
      action_key { "registration_complete" }
    end
  end
end
