# frozen_string_literal: true

require 'rails_helper'

#
# RewardNotification — unit-тест фильтрации каналов по настройкам получателя.
#
RSpec.describe RewardNotification, type: :notification do
  let(:recipient) { create(:user, :with_setting) }
  let(:params) { { amount: 10, action_key: 'poi_create', event_type: 'reward_available' } }

  describe 'фильтрация по настройкам (SettingFilterable)' do
    it 'включает канал, когда мастер-флаг и событие включены' do
      recipient.setting.update!(notifications_enabled: true, reward_available_notifications_enabled: true)
      notif = described_class.with(params)
      expect(notif.notifications_enabled?(recipient)).to be true
    end

    it 'отключает канал, если событие выключено' do
      recipient.setting.update!(reward_available_notifications_enabled: false)
      notif = described_class.with(params)
      expect(notif.notifications_enabled?(recipient)).to be false
    end

    it 'отключает канал, если мастер-флаг выключен' do
      recipient.setting.update!(notifications_enabled: false, reward_available_notifications_enabled: true)
      notif = described_class.with(params)
      expect(notif.notifications_enabled?(recipient)).to be false
    end

    it 'использует reward_locked для под-события locked' do
      recipient.setting.update!(reward_available_notifications_enabled: true, reward_locked_notifications_enabled: false)
      locked = described_class.with(params.merge(event_type: 'reward_locked'))
      expect(locked.notifications_enabled?(recipient)).to be false
    end
  end
end
