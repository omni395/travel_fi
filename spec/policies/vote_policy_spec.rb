# frozen_string_literal: true

require 'rails_helper'

#
# VotePolicy — unit-спек доступа к голосам сообщества.
#
# Покрывает новый guard статус active: suspended/прочие «заблокированные»
# статусы НЕ могут голосовать (см. UserAccessService.can_interact?).
#
RSpec.describe VotePolicy, type: :policy do
  let(:poi) { create(:poi, status: :approved) }

  describe '#create?' do
    it 'разрешает голосовать активному юзеру за чужую видимую точку' do
      author = create(:user)
      poi = create(:poi, user: author, status: :approved)
      voter = create(:user, :active)

      expect(described_class.new(voter, poi).create?).to be_truthy
    end

    it 'запрещает голосовать suspended-юзеру (независимо от авторства)' do
      suspended = create(:user, :suspended)
      # Точка чужого автора — единственное условие (кроме статуса) легитимности.
      author = create(:user)
      other_poi = create(:poi, user: author, status: :approved)

      expect(described_class.new(suspended, other_poi).create?).to be_falsey
    end

    it 'запрещает голосовать гостю и невидимой точке' do
      expect(described_class.new(nil, poi).create?).to be_falsey

      pending_poi = create(:poi, status: :pending)
      expect(described_class.new(create(:user), pending_poi).create?).to be_falsey
    end
  end
end
