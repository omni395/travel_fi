# frozen_string_literal: true

require 'rails_helper'

#
# PoiStatusNotification — unit-тест фильтрации по настройкам my_poi_status.
#
RSpec.describe PoiStatusNotification, type: :notification do
  let(:recipient) { create(:user, :with_setting) }
  let(:poi) { create(:poi) }

  describe 'фильтрация по настройкам' do
    it 'включает канал, когда событие и мастер-флаг включены' do
      recipient.setting.update!(notifications_enabled: true, my_poi_status_notifications_enabled: true)
      notif = described_class.with(poi: poi, event_type: 'approved')
      expect(notif.notifications_enabled?(recipient)).to be true
    end

    it 'отключает, если my_poi_status_notifications_enabled = false' do
      recipient.setting.update!(my_poi_status_notifications_enabled: false)
      notif = described_class.with(poi: poi, event_type: 'approved')
      expect(notif.notifications_enabled?(recipient)).to be false
    end

    it 'отключает по email, если email_enabled мастер-флаг = false' do
      recipient.setting.update!(email_enabled: false, my_poi_status_email_enabled: true)
      notif = described_class.with(poi: poi, event_type: 'approved')
      expect(notif.email_enabled?(recipient)).to be false
    end
  end
end
