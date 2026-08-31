# frozen_string_literal: true

require 'rails_helper'

#
# Vote — unit-спек модели голосования сообщества.
#
RSpec.describe Vote, type: :model do
  let(:user) { create(:user) }
  let(:poi) { create(:poi) }

  describe 'валидации' do
    it 'допускает value = 1 (апрув)' do
      vote = described_class.new(votable: poi, user: user, value: 1)
      expect(vote).to be_valid
    end

    it 'допускает value = -1 (дизлайк)' do
      vote = described_class.new(votable: poi, user: user, value: -1)
      expect(vote).to be_valid
    end

    it 'отклоняет невалидный value (0)' do
      vote = described_class.new(votable: poi, user: user, value: 0)
      expect(vote).not_to be_valid
    end
  end

  describe 'уникальность (один юзер = один голос за сущность)' do
    it 'не даёт создать второй голос тем же юзером за тот же votable' do
      described_class.create!(votable: poi, user: user, value: 1)

      duplicate = described_class.new(votable: poi, user: user, value: -1)
      expect(duplicate).not_to be_valid
      expect { duplicate.save! }.to raise_error(ActiveRecord::RecordInvalid)
    end
  end

  describe 'скоупы ups/downs' do
    it 'корректно разбивает голоса по value' do
      other = create(:user)
      create(:vote, votable: poi, user: user, value: 1)
      create(:vote, votable: poi, user: other, value: -1)

      expect(poi.votes.ups.count).to eq(1)
      expect(poi.votes.downs.count).to eq(1)
    end
  end

  describe '.voted_by?' do
    it 'возвращает true если юзер голосовал за сущность' do
      create(:vote, votable: poi, user: user, value: 1)
      expect(poi.votes.voted_by?(user)).to be true
    end

    it 'возвращает false если юзер не голосовал' do
      expect(poi.votes.voted_by?(user)).to be false
    end
  end

  describe 'PaperTrail' do
    it 'создаёт версию аудита для голоса' do
      described_class.create!(votable: poi, user: user, value: 1)
      expect(poi.votes.first.versions.count).to eq(1)
    end
  end
end
