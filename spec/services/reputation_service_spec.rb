# frozen_string_literal: true

require 'rails_helper'

#
# ReputationService — unit-спек пересчёта репутации автора по голосам.
#
RSpec.describe ReputationService, type: :service do
  let(:author) { create(:user) }

  describe '.reckon!' do
    it 'копится репутация: +1 за апрув, -1 за дизлайк за контент автора' do
      poi = create(:poi, user: author)
      create(:vote, votable: poi, user: create(:user), value: 1)
      create(:vote, votable: poi, user: create(:user), value: -1)

      described_class.reckon!(author)
      expect(author.reload.reputation).to eq(0)
    end

    it 'суммирует голоса по POI, фото и комментариям автора' do
      poi = create(:poi, user: author)
      comment = create(:poi_comment, user: author)
      create(:vote, votable: poi, user: create(:user), value: 1)
      create(:vote, votable: comment, user: create(:user), value: 1)
      create(:vote, votable: comment, user: create(:user), value: 1)

      described_class.reckon!(author)
      expect(author.reload.reputation).to eq(3)
    end

    it 'не учитывает чужие сущности' do
      other_author = create(:user)
      other_poi = create(:poi, user: other_author)
      create(:vote, votable: other_poi, user: create(:user), value: 1)

      described_class.reckon!(author)
      expect(author.reload.reputation).to eq(0)
    end

    it 'идемпотентен при повторном вызове (всегда актуальная сумма)' do
      poi = create(:poi, user: author)
      create(:vote, votable: poi, user: create(:user), value: 1)

      described_class.reckon!(author)
      described_class.reckon!(author)
      expect(author.reload.reputation).to eq(1)
    end
  end
end
