# frozen_string_literal: true

require 'rails_helper'

#
# TokenTransactionRetryJob — unit-тесты периодического авто-ретрая упавших relay.
#
# Покрытие:
# 1. Переотправляет failed+instant начисления с пустым tx_hash.
# 2. Пропускает failed-начисления с уже заполненным tx_hash (уже отправленные).
# 3. Пропускает vesting-начисления, пока они не разблокированы (locked).
#
RSpec.describe TokenTransactionRetryJob, type: :job do
  let(:user) { create(:user) }

  before do
    # Перехватываем постановку в очередь, чтобы не трогать реальную SolidQueue.
    allow(TokenTransactionRelayJob).to receive(:perform_later).and_return(nil)
  end

  def build_tx!(action_key:, status:, tx_hash: nil, created_at: Time.current)
    create(
      :token_transaction,
      user: user,
      action_key: action_key,
      status: status,
      tx_hash: tx_hash,
      created_at: created_at
    )
  end

  describe '#perform' do
    it 'переотправляет failed мгновенное начисление без tx_hash' do
      failed_reg = build_tx!(action_key: 'registration', status: :failed)

      described_class.perform_now

      expect(TokenTransactionRelayJob).to have_received(:perform_later).with(failed_reg.id)
    end

    it 'пропускает failed-начисление с уже существующим tx_hash' do
      build_tx!(action_key: 'registration', status: :failed, tx_hash: '0xabc')

      described_class.perform_now

      expect(TokenTransactionRelayJob).not_to have_received(:perform_later)
    end

    it 'пропускает заблокированный (locked) vesting-бонус реферера до разблокировки' do
      # referral_bonus_referrer теперь vesting; свежая запись ещё locked (не available).
      locked_referrer = build_tx!(action_key: 'referral_bonus_referrer', status: :failed)

      described_class.perform_now

      expect(TokenTransactionRelayJob).not_to have_received(:perform_later).with(locked_referrer.id)
    end
  end
end
