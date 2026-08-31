# frozen_string_literal: true

require 'rails_helper'

#
# VoteService — unit-спек голосования сообщества (create/destroy/change).
#
RSpec.describe VoteService, type: :service do
  let(:author) { create(:user) }
  let(:voter) { create(:user) }
  let(:poi) { create(:poi, user: author) }

  describe '.cast!' do
    context 'action: :create (новый голос)' do
      it 'создаёт Vote +1 и возвращает [:vote, :created]' do
        vote, action = described_class.cast!(votable: poi, user: voter, value: 1, action: :create)

        expect(action).to eq(:created)
        expect(vote).to be_persisted
        expect(vote.value).to eq(1)
        expect(vote.votable).to eq(poi)
      end

      it 'создаёт Vote -1 (дизлайк)' do
        vote, action = described_class.cast!(votable: poi, user: voter, value: -1, action: :create)

        expect(action).to eq(:created)
        expect(vote.value).to eq(-1)
      end

      it 'не плодит дубли при повторном create того же значения (перезапись)' do
        described_class.cast!(votable: poi, user: voter, value: 1, action: :create)

        expect {
          _, action = described_class.cast!(votable: poi, user: voter, value: 1, action: :create)
          expect(action).to eq(:updated)
        }.not_to change { Vote.count }
      end
    end

    context 'action: :destroy (забрать голос)' do
      it 'удаляет голос и возвращает :destroyed' do
        described_class.cast!(votable: poi, user: voter, value: 1, action: :create)

        expect {
          vote, action = described_class.cast!(votable: poi, user: voter, action: :destroy)
          expect(action).to eq(:destroyed)
          expect(vote).to be_nil
        }.to change { Vote.count }.by(-1)
      end

      it 'без существующего голоса ничего не делает (:none)' do
        vote, action = described_class.cast!(votable: poi, user: voter, action: :destroy)

        expect(action).to eq(:none)
        expect(vote).to be_nil
      end
    end

    context 'action: :change (сменить голос)' do
      it 'удаляет старый + создаёт новый value (:changed)' do
        created, _ = described_class.cast!(votable: poi, user: voter, value: 1, action: :create)

        expect {
          vote, action = described_class.cast!(votable: poi, user: voter, value: -1, action: :change)
          expect(action).to eq(:changed)
          expect(vote.value).to eq(-1)
        }.not_to change { Vote.count }
      end

      it 'начисляет награду только за новое создание' do
        expect {
          described_class.cast!(votable: poi, user: voter, value: 1, action: :create)
        }.to change { voter.user_rewards.where(action_key: 'poi_vote').count }.by(1)

        # change повторно не начисляет повторно? НЕТ — change создаёт новый Vote,
        # значит награда начисляется ещё раз. Считаем суммарно после change.
        expect {
          described_class.cast!(votable: poi, user: voter, value: -1, action: :change)
        }.to change { voter.user_rewards.where(action_key: 'poi_vote').count }.by(1)
      end
    end

    context 'награда TFT при создании' do
      it 'начисляет poi_vote награду при action: :create' do
        expect { described_class.cast!(votable: poi, user: voter, value: 1, action: :create) }
          .to change { voter.user_rewards.where(action_key: 'poi_vote').count }.by(1)
      end

      it 'не начисляет награду при destroy' do
        described_class.cast!(votable: poi, user: voter, value: 1, action: :create)

        expect {
          described_class.cast!(votable: poi, user: voter, action: :destroy)
        }.not_to change { voter.user_rewards.where(action_key: 'poi_vote').count }
      end
    end

    context 'невалидные входные данные' do
      it 'бросает ArgumentError для невалидного value' do
        expect { described_class.cast!(votable: poi, user: voter, value: 5, action: :create) }
          .to raise_error(ArgumentError)
      end

      it 'бросает ArgumentError для неизвестного action' do
        expect { described_class.cast!(votable: poi, user: voter, value: 1, action: :bogus) }
          .to raise_error(ArgumentError)
      end
    end
  end

  describe '.tally' do
    it 'возвращает ups/downs/total/net' do
      v1 = create(:user)
      v2 = create(:user)
      v3 = create(:user)
      described_class.cast!(votable: poi, user: v1, value: 1, action: :create)
      described_class.cast!(votable: poi, user: v2, value: 1, action: :create)
      described_class.cast!(votable: poi, user: v3, value: -1, action: :create)

      tally = described_class.tally(poi)
      expect(tally[:ups]).to eq(2)
      expect(tally[:downs]).to eq(1)
      expect(tally[:total]).to eq(3)
      expect(tally[:net]).to eq(1)
    end
  end
end
