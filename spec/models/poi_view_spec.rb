# frozen_string_literal: true

require 'rails_helper'

#
# PoiView — unit-тесты модели просмотра POI.
#
RSpec.describe PoiView, type: :model do
  describe 'валидации' do
    it 'требует все ассоциации' do
      expect(build(:poi_view)).to be_valid
    end

    it 'не допускает дубль (user, poi)' do
      first = create(:poi_view)
      expect(build(:poi_view, user: first.user, poi: first.poi)).not_to be_valid
    end
  end

  describe '#recency_weight' do
    it 'свежий просмотр имеет вес близкий к 1' do
      view = create(:poi_view, viewed_at: Time.current)
      expect(view.recency_weight).to be > 0.9
    end

    it 'старый просмотр имеет меньший вес' do
      view = create(:poi_view, viewed_at: 21.days.ago)
      expect(view.recency_weight).to be < 0.3
    end
  end
end
