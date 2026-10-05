# frozen_string_literal: true

require 'rails_helper'

#
# UserAccessService — unit-спек единого классификатора доступа по статусу.
#
# Покрывает матрицу «кто что может»:
#   can_view_details?  — детали точки видят active и suspended, но не
#                        guest/pending/inactive/deleted/banned;
#   can_interact?      — комментировать/голосовать/фото — только active;
#   interaction_block  — причина блока для suspended (с датой разблокировки).
#
RSpec.describe UserAccessService, type: :service do
  describe '.can_view_details?' do
    it 'true для active и suspended' do
      expect(described_class.can_view_details?(create(:user, :active))).to be_truthy
      expect(described_class.can_view_details?(create(:user, :suspended))).to be_truthy
    end

    it 'false для guest/pending/inactive/deleted/banned' do
      expect(described_class.can_view_details?(nil)).to be_falsey
      expect(described_class.can_view_details?(create(:user, :pending))).to be_falsey
      expect(described_class.can_view_details?(create(:user, :inactive))).to be_falsey
      expect(described_class.can_view_details?(create(:user, :banned))).to be_falsey
    end
  end

  describe '.can_interact?' do
    it 'true только для active' do
      expect(described_class.can_interact?(create(:user, :active))).to be_truthy
      expect(described_class.can_interact?(create(:user, :suspended))).to be_falsey
      expect(described_class.can_interact?(create(:user, :pending))).to be_falsey
      expect(described_class.can_interact?(create(:user, :inactive))).to be_falsey
      expect(described_class.can_interact?(create(:user, :banned))).to be_falsey
      expect(described_class.can_interact?(nil)).to be_falsey
    end
  end

  describe '.interaction_block' do
    it 'возвращает причину :suspended с датой разблокировки' do
      user = create(:user, :suspended, suspended_until: 3.days.from_now)

      block = described_class.interaction_block(user)

      expect(block[:reason]).to eq(:suspended)
      expect(block[:unlock_at]).to be_within(1.second).of(user.suspended_until)
    end

    it 'nil для активного юзера и гостя' do
      expect(described_class.interaction_block(create(:user, :active))).to be_nil
      expect(described_class.interaction_block(nil)).to be_nil
    end
  end
end
