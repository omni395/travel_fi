# frozen_string_literal: true

require 'rails_helper'
require 'uri'

#
# TokenTransactionService — ИНТЕГРАЦИОННЫЙ тест on-chain relay на РЕАЛЬНЫЙ блокчейн
# (Base Sepolia). В отличие от unit-спека здесь НЕ мокается RPC: транзакция реально
# подписывается и отправляется eth_sendRawTransaction, затем верифицируется receipt.
#
# Opt-in: запускается ТОЛЬКО при ENV['RUN_BLOCKCHAIN_INTEGRATION'] == '1', чтобы
# обычный полный suite (CI/локальный) не шёл в сеть и не тратил тестнет-газ.
#   RUN_BLOCKCHAIN_INTEGRATION=1 rspec spec/services/token_transaction_service_integration_spec.rb
#
# Все необходимые адреса/ключи читаются из .env (dotenv-rails):
#   RPC_URL, OPERATOR_PRIVATE_KEY, TOKEN_CONTRACT_ADDRESS, REWARDS_CONTRACT_ADDRESS, CHAIN_ID
#
RSpec.describe 'TokenTransactionService (blockchain integration)', :integration do
  before do
    skip 'Set RUN_BLOCKCHAIN_INTEGRATION=1 to run blockchain integration test' unless ENV['RUN_BLOCKCHAIN_INTEGRATION'] == '1'
  end

  # Реальная сеть: разрешаем только RPC-хост (не весь интернет).
  before(:all) do
    rpc_host = URI.parse(ENV.fetch('RPC_URL')).host
    WebMock.disable_net_connect!(allow: rpc_host)
  end

  after(:all) do
    # Возврат дефолтного поведения WebMock (запрет всех сетевых вызовов).
    WebMock.disable_net_connect!
  end

  it 'реально отправляет transfer на reward-контракт и подтверждает receipt status 0x1' do
    # Предусловия из .env (без стабов ENV — читаются реальные значения).
    %w[RPC_URL OPERATOR_PRIVATE_KEY TOKEN_CONTRACT_ADDRESS REWARDS_CONTRACT_ADDRESS CHAIN_ID].each do |key|
      expect(ENV[key]).to be_present, "Missing ENV['#{key}'] — проверь .env"
    end

    user = create(:user)
    wallet = WalletService.create_hidden_wallet(user: user)
    tx = create(:token_transaction, user: user, wallet: wallet, status: :pending, amount: 10)

    result = TokenTransactionService.relay!(tx)

    expect(result).to be_present, 'relay! вернул nil — транзакция не прошла (см. логи; вероятен revert из-за пустого reward pool)'
    expect(result).to start_with('0x')

    # Перечитываем запись: статус confirmed, claimed=true, tx_hash верифицирован.
    tx.reload
    expect(tx.status).to eq('confirmed')
    expect(tx.claimed).to be(true)
    expect(tx.tx_hash).to eq(result)
    expect(tx.wallet_id).to eq(wallet.id)

    Rails.logger.info("INTEGRATION: relay confirmed tx=#{result} (Base Sepolia)")
  end
end
