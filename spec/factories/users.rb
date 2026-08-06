# frozen_string_literal: true

#
# Фабрика User — создаёт пользователя с валидными атрибутами.
# Роль :user назначается автоматически через after_create в модели.
#
FactoryBot.define do
  factory :user do
    sequence(:email) { |n| "user#{n}@example.com" }
    name { "Test User" }
    password { "password123" }
    password_confirmation { "password123" }
    status { :active }
    confirmed_at { Time.current }

    trait :pending do
      status { :pending }
    end

    trait :inactive do
      status { :inactive }
    end

    # Юзер без подтверждения email (для confirmation/wallet тестов).
    # confirmed_at = nil → Devise генерирует confirmation_token при создании.
    trait :unconfirmed do
      status { :pending }
      confirmed_at { nil }
    end

    trait :suspended do
      status { :suspended }
    end

    trait :banned do
      status { :banned }
    end

    trait :admin do
      after(:create) { |user| user.add_role(:admin) }
    end

    trait :moderator do
      after(:create) { |user| user.add_role(:moderator) }
    end

    # Для system-тестов «браузер А → браузер Б»: юзер с настройками уведомлений
    trait :with_setting do
      after(:create) { |user| user.setting || create(:setting, user: user) }
    end
  end
end
