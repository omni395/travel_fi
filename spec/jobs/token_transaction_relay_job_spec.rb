# frozen_string_literal: true

require 'rails_helper'

#
# TokenTransactionRelayJob — unit-спек on-chain relay-задачи.
#
RSpec.describe TokenTransactionRelayJob, type: :job do
  it 'вызывает TokenTransactionService.relay! для существующей транзакции' do
    tx = create(:token_transaction)

    expect(TokenTransactionService).to receive(:relay!).with(tx)

    described_class.perform_now(tx.id)
  end

  it 'ничего не делает для несуществующей транзакции' do
    expect(TokenTransactionService).not_to receive(:relay!)

    described_class.perform_now(999_999)
  end
end
