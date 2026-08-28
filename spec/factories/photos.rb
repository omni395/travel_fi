# frozen_string_literal: true

#
# Фабрика Photo — фотография галереи POI.
# Прикрепляет тестовое изображение к photo.image (ActiveStorage).
#
FactoryBot.define do
  factory :photo do
    association :poi
    association :user
    sequence(:position) { |n| n }

    after(:build) do |photo|
      unless photo.image.attached?
        photo.image.attach(
          io: File.open(Rails.root.join('spec/fixtures/files/photo.png')),
          filename: 'photo.png',
          content_type: 'image/png'
        )
      end
    end
  end
end
