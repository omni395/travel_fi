# frozen_string_literal: true

require 'rails_helper'

#
# ModerationService — unit-спек пороговой авто-модерации.
#
# Покрывает согласованный алгоритм бейджа:
#   ups/downs >= threshold → бейдж; конфликт (оба >= порога) решает net;
#   net <= 0 (в т.ч. паритет) → :rejected.
#
RSpec.describe ModerationService, type: :service do
  let(:author) { create(:user) }
  let!(:poi) { create(:poi, user: author, status: :approved) }

  # Создаёт N апрув-голосов от разных юзеров
  def up_votes(n)
    n.times { create(:vote, votable: poi, user: create(:user), value: 1) }
  end

  # Создаёт N дизлайк-голосов от разных юзеров
  def down_votes(n)
    n.times { create(:vote, votable: poi, user: create(:user), value: -1) }
  end

  describe '.badge_state' do
    context 'только апрувы' do
      it ':approved когда ups >= порога' do
        up_votes(ModerationService.threshold)
        expect(described_class.badge_state(poi)).to eq(:approved)
      end

      it ':none когда ups < порога' do
        up_votes(ModerationService.threshold - 1)
        expect(described_class.badge_state(poi)).to eq(:none)
      end
    end

    context 'только дизлайки' do
      it ':rejected когда downs >= порога' do
        down_votes(ModerationService.threshold)
        expect(described_class.badge_state(poi)).to eq(:rejected)
      end

      it ':none когда downs < порога' do
        down_votes(ModerationService.threshold - 1)
        expect(described_class.badge_state(poi)).to eq(:none)
      end
    end

    context 'конфликт (оба >= порога)' do
      it ':approved когда net > 0 (10+ против 9-)' do
        up_votes(10)
        down_votes(9)
        expect(described_class.badge_state(poi, threshold: 10)).to eq(:approved)
      end

      it ':rejected когда дизлайков больше (10+ против 11-)' do
        up_votes(10)
        down_votes(11)
        expect(described_class.badge_state(poi, threshold: 10)).to eq(:rejected)
      end

      it ':rejected при паритете (10+ против 10-, net=0) — консервативно' do
        up_votes(10)
        down_votes(10)
        expect(described_class.badge_state(poi, threshold: 10)).to eq(:rejected)
      end
    end
  end

  describe '.evaluate!' do
    context 'для POI' do
      it 'одобренного сообществом выставляет moderation_source community и не трогает status' do
        up_votes(ModerationService.threshold)
        state = described_class.evaluate!(poi)

        expect(state).to eq(:approved)
        expect(poi.reload.moderation_source_community?).to be true
        expect(poi.status).to eq('approved') # статус НЕ меняется
      end

      it 'отклонённого сообществом ставит community_rejected, статус/видимость не трогает' do
        down_votes(ModerationService.threshold)
        state = described_class.evaluate!(poi)

        expect(state).to eq(:rejected)
        expect(poi.reload.community_rejected?).to be true
        expect(poi.status).to eq('approved')
      end

      it 'для pending точки бейджи не выставляет (админ решает всё)' do
        pending_poi = create(:poi, user: author, status: :pending)
        create(:vote, votable: pending_poi, user: create(:user), value: 1)
        create(:vote, votable: pending_poi, user: create(:user), value: 1)

        described_class.evaluate!(pending_poi)
        expect(pending_poi.reload.moderation_source).to eq('admin')
        expect(pending_poi.community_rejected?).to be false
      end
    end

    context 'для Photo/PoiComment (поведение отложено — только репутация)' do
      it 'не падает и пересчитывает репутацию автора' do
        comment = create(:poi_comment, user: author)
        create(:vote, votable: comment, user: create(:user), value: 1)

        expect { described_class.evaluate!(comment) }.not_to raise_error
        expect(author.reload.reputation).to eq(1)
      end
    end
  end
end
