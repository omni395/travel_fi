# frozen_string_literal: true

require 'rails_helper'

#
# Admin::DashboardService — unit-спек: статистика дашборда
# (вынесена из UserService по принципу «одна сущность — один сервис»).
#
RSpec.describe Admin::DashboardService, type: :service do
  describe '.stats' do
    it 'считает total/active/pending/restricted по статусам' do
      create(:user, :active)
      create(:user, :pending, :unconfirmed)
      create(:user, :suspended)
      create(:user, :banned)

      stats = described_class.stats

      expect(stats[:total]).to eq(4)
      expect(stats[:active]).to eq(1)
      expect(stats[:pending]).to eq(1)
      expect(stats[:restricted]).to eq(2)
    end
  end
end
