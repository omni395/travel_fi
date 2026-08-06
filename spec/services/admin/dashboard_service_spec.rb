# frozen_string_literal: true

require 'rails_helper'

#
# Admin::DashboardService — unit-спек: статистика дашборда
# (вынесена из UserService по принципу «одна сущность — один сервис»).
#
RSpec.describe Admin::DashboardService, type: :service do
  describe '.stats' do
    it 'считает total_users/active_users/suspended_users/new_users_today' do
      create(:user, :active)
      create(:user, :pending, :unconfirmed)
      create(:user, :suspended)
      create(:user, :banned)

      stats = described_class.stats

      # Ключи совпадают с типами карточек DashboardComponent (ROADMAP 3.1)
      expect(stats[:total_users]).to eq(4)
      expect(stats[:active_users]).to eq(1)
      expect(stats[:suspended_users]).to eq(2)
      # Все юзеры созданы сейчас → зарегистрированные сегодня (не pending!)
      expect(stats[:new_users_today]).to eq(4)
    end
  end
end
