# frozen_string_literal: true

require 'rails_helper'

#
# PoiViewService — unit-тесты фиксации просмотра карточки POI.
#
RSpec.describe PoiViewService, type: :service do
  let(:user) { create(:user) }
  let(:poi) { create(:poi) }

  describe '#record' do
    it 'создаёт запись просмотра с категорией' do
      view = PoiViewService.record(user: user, poi: poi)

      expect(view).to be_persisted
      expect(view.poi_category_id).to eq(poi.poi_category_id)
      expect(view.user).to eq(user)
      expect(view.poi).to eq(poi)
    end

    it 'не создаёт дубль при повторном просмотре, а обновляет viewed_at' do
      first = PoiViewService.record(user: user, poi: poi)
      original = first.viewed_at
      first.update!(viewed_at: 1.hour.ago)

      second = PoiViewService.record(user: user, poi: poi)
      expect(second.id).to eq(first.id)
      expect(second.viewed_at).to be > original
      expect(PoiView.where(user: user, poi: poi).count).to eq(1)
    end

    it 'возвращает nil без юзера или точки' do
      expect(PoiViewService.record(user: nil, poi: poi)).to be_nil
      expect(PoiViewService.record(user: user, poi: nil)).to be_nil
    end
  end
end
