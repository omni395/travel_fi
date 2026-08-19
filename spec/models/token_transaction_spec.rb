# frozen_string_literal: true

require 'rails_helper'

#
# TokenTransaction — unit-тесты модели журнала движения токенов TFT.
#
# Покрытие:
# 1. Валидации (amount > 0, action_key, chain_id, enum direction/status)
# 2. Связи (user, wallet optional, user_reward optional)
# 3. short_hash — выжимка хэша 4+4 для explorer-ссылки
# 4. explorer_url — URL транзакции в explorer
#
RSpec.describe TokenTransaction, type: :model do
  let(:user) { create(:user) }

  describe 'валидации' do
    it 'валиден с корректными атрибутами' do
      tx = build(:token_transaction, user: user)
      expect(tx).to be_valid
    end

    it 'требует amount > 0' do
      expect(build(:token_transaction, user: user, amount: 0)).not_to be_valid
    end

    it 'требует action_key' do
      expect(build(:token_transaction, user: user, action_key: nil)).not_to be_valid
    end

    it 'требует chain_id' do
      expect(build(:token_transaction, user: user, chain_id: nil)).not_to be_valid
    end

    it 'валидирует направление (credit/debit)' do
      expect(build(:token_transaction, user: user, direction: :bogus)).not_to be_valid
      expect(build(:token_transaction, user: user, direction: :credit)).to be_valid
      expect(build(:token_transaction, user: user, direction: :debit)).to be_valid
    end

    it 'валидирует статус (pending/confirmed/failed)' do
      expect(build(:token_transaction, user: user, status: :bogus)).not_to be_valid
      expect(build(:token_transaction, user: user, status: :pending)).to be_valid
      expect(build(:token_transaction, user: user, status: :confirmed)).to be_valid
    end
  end

  describe 'связи' do
    it 'принадлежит пользователю' do
      tx = create(:token_transaction, user: user)
      expect(tx.user).to eq(user)
    end

    it 'допускает отсутствие кошелька (email-регистрация без подтверждения)' do
      tx = create(:token_transaction, user: user, wallet: nil)
      expect(tx.wallet).to be_nil
    end

    it 'допускает отсутствие user_reward (будущий debit/spend)' do
      tx = create(:token_transaction, user: user, user_reward: nil)
      expect(tx.user_reward).to be_nil
    end
  end

  describe '#short_hash' do
    it 'возвращает выжимку 4+4 символа' do
      tx = build(:token_transaction, user: user, tx_hash: '0x1234567890abcdef')
      expect(tx.short_hash).to eq('0x12...cdef')
    end

    it 'возвращает nil без tx_hash' do
      tx = build(:token_transaction, user: user, tx_hash: nil)
      expect(tx.short_hash).to be_nil
    end
  end

  describe '#explorer_url' do
    before do
      # verify_partial_doubles=true: точечный стаб ENV ломает DatabaseCleaner.clean
      # (читает DATABASE_CLEANER_ALLOW_REMOTE_DATABASE_URL). and_call_original
      # оставляет остальные ключи реальными.
      allow(ENV).to receive(:[]).and_call_original
    end

    it 'строит ссылку на транзакцию в explorer' do
      allow(ENV).to receive(:[]).with('CHAIN_EXPLORER_URL').and_return('https://sepolia.etherscan.io/')
      tx = build(:token_transaction, user: user, tx_hash: '0xabc123')
      expect(tx.explorer_url).to eq('https://sepolia.etherscan.io/tx/0xabc123')
    end

    it 'возвращает nil без tx_hash или без explorer URL' do
      tx = build(:token_transaction, user: user, tx_hash: '0xabc123')
      allow(ENV).to receive(:[]).with('CHAIN_EXPLORER_URL').and_return(nil)
      expect(tx.explorer_url).to be_nil
    end
  end

  describe '#instant? / #lock_days (антифрод реферера)' do
    it 'registration — мгновенное начисление (lock=0)' do
      tx = build(:token_transaction, user: user, action_key: 'registration')
      expect(tx.instant?).to be true
      expect(tx.lock_days).to eq(0)
    end

    it 'referral_bonus_new_user — мгновенное начисление (бонус самому новичку)' do
      tx = build(:token_transaction, user: user, action_key: 'referral_bonus_new_user')
      expect(tx.instant?).to be true
      expect(tx.lock_days).to eq(0)
    end

    it 'referral_bonus_referrer — НЕ мгновенное (vesting-лок; антифрод рефереру)' do
      tx = build(:token_transaction, user: user, action_key: 'referral_bonus_referrer')
      expect(tx.instant?).to be false
      expect(tx.lock_days).to eq(GamificationService.pool_lock_days)
    end
  end

  describe 'скоупы available / locked (учитывают мгновенные начисления, БАГ A)' do
    let(:lock_days) { GamificationService.pool_lock_days }

    it 'available: мгновенное начисление (registration) доступно сразу, без ожидания лок-периода' do
      tx = create(:token_transaction, user: user, action_key: 'registration')

      expect(TokenTransaction.available).to include(tx)
      expect(user.token_transactions.available).to include(tx)
    end

    it 'available: vesting-начисление появляется только после истечения лок-периода' do
      tx = create(:token_transaction, user: user, action_key: 'poi_create')
      expect(TokenTransaction.available).not_to include(tx)

      # Передвигаем created_at за границу lock-периода — начисление разблокируется.
      tx.update_column(:created_at, (lock_days + 1).days.ago)
      expect(TokenTransaction.available).to include(tx)
    end

    it 'locked: мгновенное начисление НЕ попадает в Locked (даже свежесозданное)' do
      tx = create(:token_transaction, user: user, action_key: 'referral_bonus_new_user')

      expect(TokenTransaction.locked).not_to include(tx)
      expect(user.token_transactions.locked).not_to include(tx)
    end

    it 'locked: vesting-начисление попадает в Locked, пока не истёк лок-период' do
      tx = create(:token_transaction, user: user, action_key: 'poi_create')

      expect(TokenTransaction.locked).to include(tx)
    end

    it 'available/locked суммарно не пересекаются и согласованы с методами инстанса' do
      instant = create(:token_transaction, user: user, action_key: 'registration')
      vesting = create(:token_transaction, user: user, action_key: 'poi_create')

      expect(instant.available?).to be(true)
      expect(instant.locked?).to be(false)
      expect(vesting.available?).to be(false)
      expect(vesting.locked?).to be(true)

      expect(TokenTransaction.available).to include(instant)
      expect(TokenTransaction.available).not_to include(vesting)
      expect(TokenTransaction.locked).to include(vesting)
      expect(TokenTransaction.locked).not_to include(instant)
    end
  end
end
