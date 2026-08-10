# frozen_string_literal: true

require 'rails_helper'

#
# GamificationService — unit-спек наград токенами TFT.
#
# Покрытие:
# 1. award! начисляет сумму из config/gamification.yml в user_rewards
# 2. Нет начисления для отсутствующего ключа
# 3. Бейджи: first_poi (badge_id 2) при условии user.pois.count == 1
#
RSpec.describe GamificationService, type: :service do
  let(:rewards) { YAML.safe_load_file(Rails.root.join('config/gamification.yml'))['rewards'] }
  let(:user) { create(:user) }

  describe '.award!' do
    it 'начисляет токены TFT из конфига в user_rewards (poi_create)' do
      amount = rewards['poi_create'].to_d

      expect { described_class.award!(:poi_create, user) }
        .to change { user.reload.token_balance }.by(amount)

      reward = user.user_rewards.last
      expect(reward.action_key).to eq('poi_create')
      expect(reward.amount).to eq(amount)
    end

    it 'начисляет comment_create из конфига' do
      amount = rewards['comment_create'].to_d

      expect { described_class.award!(:comment_create, user) }
        .to change { user.reload.token_balance }.by(amount)
    end

    it 'не начисляет для отсутствующего ключа' do
      expect { described_class.award!(:nonexistent_key, user) }
        .not_to change { user.reload.token_balance }
    end

    it 'выдаёт бейдж first_poi (badge_id 2) при первом POI' do
      create(:poi, user: user)

      described_class.award!(:poi_create, user)

      expect(user.reload.earned_badge?(2)).to be(true)
    end
  end

  describe 'журнал TokenTransaction' do
    it 'создаёт TokenTransaction (credit, pending, claimed=false, без tx_hash) для начисления' do
      amount = rewards['registration'].to_d

      expect { described_class.award!(:registration, user) }
        .to change { user.reload.token_transactions.count }.by(1)

      tx = user.token_transactions.last
      expect(tx.direction).to eq('credit')
      expect(tx.status).to eq('pending')
      expect(tx.claimed).to be(false)
      expect(tx.amount).to eq(amount)
      expect(tx.chain_id).to be_present
      expect(tx.tx_hash).to be_nil
    end

    it 'создаёт UserReward и TokenTransaction в одной транзакции' do
      expect { described_class.award!(:registration, user) }
        .to change { user.reload.user_rewards.count }.by(1)
        .and change { TokenTransaction.count }.by(1)
    end
  end

  describe 'лок-модель (instant vs vesting)' do
    it 'начисление registration — мгновенное (instant?, lock_days = 0), ставят relay-джоб' do
      expect(TokenTransactionRelayJob).to receive(:perform_later).once

      described_class.award!(:registration, user)

      tx = user.reload.token_transactions.last
      expect(tx.instant?).to be(true)
      expect(tx.lock_days).to eq(0)
      expect(tx.available?).to be(true)
      expect(tx.locked?).to be(false)
    end

    it 'начисление poi_create — vesting (не instant), relay-джоб НЕ ставится' do
      expect(TokenTransactionRelayJob).not_to receive(:perform_later)

      described_class.award!(:poi_create, user)

      tx = user.reload.token_transactions.last
      expect(tx.instant?).to be(false)
      expect(tx.lock_days).to eq(described_class.pool_lock_days)
      expect(tx.locked?).to be(true) # ещё не разблокировано
      expect(tx.available?).to be(false)
    end
  end

  describe 'pool config (config/gamification.yml)' do
    it 'читает lock_days' do
      expect(described_class.pool_lock_days).to eq(rewards_config_dig('pool', 'lock_days').to_i)
    end

    it 'читает warning_balance' do
      expect(described_class.pool_warning_balance).to eq(rewards_config_dig('pool', 'warning_balance').to_i)
    end

    it 'читает critical_balance' do
      expect(described_class.pool_critical_balance).to eq(rewards_config_dig('pool', 'critical_balance').to_i)
    end
  end

  def rewards_config_dig(*keys)
    YAML.safe_load_file(Rails.root.join('config/gamification.yml')).dig(*keys)
  end
end
