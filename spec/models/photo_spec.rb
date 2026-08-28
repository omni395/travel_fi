# frozen_string_literal: true

require 'rails_helper'

#
# Photo — unit-спек модели фотографии галереи POI.
#
RSpec.describe Photo, type: :model do
  let(:poi) { create(:poi) }
  let(:user_a) { create(:user) }
  let(:user_b) { create(:user) }

  describe 'ассоциации и валидации' do
    it 'принадлежит POI и автору' do
      photo = create(:photo, poi: poi, user: user_a)
      expect(photo.poi).to eq(poi)
      expect(photo.user).to eq(user_a)
    end

    it 'требует наличие image (attached)' do
      photo = build(:photo, poi: poi, user: user_a)
      photo.image.purge if photo.image.attached?
      expect(photo).not_to be_valid
      expect(photo.errors[:image]).not_to be_empty
    end
  end

  describe 'скоуп author_first (свои вначале)' do
    it 'ставит свои фото первыми, затем остальные по позиции' do
      mine   = create(:photo, poi: poi, user: user_a, position: 0)
      other1 = create(:photo, poi: poi, user: user_b, position: 1)
      other2 = create(:photo, poi: poi, user: user_b, position: 2)

      ordered = poi.photos.author_first(user_a.id).to_a
      expect(ordered.map(&:id)).to eq([ mine.id, other1.id, other2.id ])
    end
  end

  describe '#url' do
    it 'возвращает URL полного блоба при отсутствии варианта' do
      photo = create(:photo, poi: poi, user: user_a)
      expect(photo.url).to be_present
      expect(photo.url).to include('/rails/active_storage/')
    end
  end
end
