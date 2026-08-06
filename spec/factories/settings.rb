# frozen_string_literal: true

#
# Фабрика Setting — настройки уведомлений пользователя.
# Создаётся через Setting.create_for_user, но фабрика нужна для прямых спеков.
#
FactoryBot.define do
  factory :setting do
    user

    new_registration_notifications_enabled { true }
    new_registration_email_enabled { false }
    new_registration_push_enabled { false }

    osm_import_notifications_enabled { true }
    osm_import_email_enabled { false }
    osm_import_push_enabled { false }

    trait :osm_import_email do
      osm_import_email_enabled { true }
    end

    trait :osm_import_push do
      osm_import_push_enabled { true }
    end

    trait :osm_import_all_off do
      osm_import_notifications_enabled { false }
      osm_import_email_enabled { false }
      osm_import_push_enabled { false }
    end
  end
end
