# frozen_string_literal: true

#
# Фабрика Vote — голос сообщества за контент (полиморфный votable).
#
FactoryBot.define do
  factory :vote do
    user
    value { 1 }

    trait :down do
      value { -1 }
    end

    trait :for_poi do
      association :votable, factory: :poi
    end

    trait :for_photo do
      association :votable, factory: :photo
    end

    trait :for_comment do
      association :votable, factory: :poi_comment
    end
  end
end
