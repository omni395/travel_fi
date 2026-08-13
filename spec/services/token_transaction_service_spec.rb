# frozen_string_literal: true

require 'rails_helper'

#
# TokenTransactionService — unit-спек on-chain relay (transfer на custodial-адрес юзера).
#
# RPC мокается через WebMock (реальная сеть в тестах НЕ затрагивается), но
# подпись транзакции (Crypto::Ethereum.sign_transaction) выполняется РЕАЛЬНО,
# чтобы доказать отсутствие NameError (баг "undefined local variable 'tx_hash'")
# и реальный eth_sendRawTransaction.
#
RSpec.describe TokenTransactionService, type: :service do
  let(:user) { create(:user) }
  let(:wallet) { WalletService.create_hidden_wallet(user: user) }
  let(:rpc_url) { 'https://base-sepolia.drpc.org' }
  let(:token_address) { '0x0000000000000000000000000000000000000001' }
  let(:rewards_contract_address) { '0x0000000000000000000000000000000000000002' }
  let(:tx_hash) { "0x#{'ab' * 32}" }

  before do
    # verify_partial_doubles=true (spec_helper): точечные стабы ENV ломают
    # DatabaseCleaner.clean (читает DATABASE_CLEANER_ALLOW_REMOTE_DATABASE_URL) и
    # WalletService (WALLET_ENCRYPTION_KEY). and_call_original оставляет остальные
    # ключи реальными, чтобы каскад очистки БД работал.
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('OPERATOR_PRIVATE_KEY').and_return("0x#{'11' * 32}")
    allow(ENV).to receive(:[]).with('RPC_URL').and_return(rpc_url)
    allow(ENV).to receive(:[]).with('TOKEN_CONTRACT_ADDRESS').and_return(token_address)
    allow(ENV).to receive(:[]).with('REWARDS_CONTRACT_ADDRESS').and_return(rewards_contract_address)
    allow(ENV).to receive(:[]).with('CHAIN_ID').and_return('0x14a34')
  end

  # Реальная быстрая верификация receipt: не ждём блоки (интервал/таймаут малы).
  before do
    stub_const("TokenTransactionService::RECEIPT_POLL_INTERVAL", 0.01)
    stub_const("TokenTransactionService::RECEIPT_MAX_WAIT", 0.2)
  end

  def stub_rpc
    stub_request(:post, rpc_url).with(body: /eth_getTransactionCount/).to_return(json('0x0'))
    stub_request(:post, rpc_url).with(body: /eth_gasPrice/).to_return(json('0x3b9aca00'))
    stub_request(:post, rpc_url).with(body: /eth_estimateGas/).to_return(json('0x1d4c0'))
    stub_request(:post, rpc_url).with(body: /eth_sendRawTransaction/).to_return(json(tx_hash))
    stub_receipt('0x1')
  end

  # Стаб eth_getTransactionReceipt с указанным статусом (0x1 success / 0x0 revert).
  #
  # @param status [String] hex-статус receipt
  #
  def stub_receipt(status)
    stub_request(:post, rpc_url).with(body: /eth_getTransactionReceipt/).to_return(
      json({ status: status, blockNumber: '0x10' })
    )
  end

  def json(result)
    {
      status: 200,
      body: { jsonrpc: '2.0', id: 1, result: result }.to_json,
      headers: { 'Content-Type' => 'application/json' }
    }
  end

  describe '.relay!' do
    it 'отправляет реальную подписанную транзакцию и подтверждает receipt status 0x1' do
      stub_rpc
      tx = create(:token_transaction, user: user, wallet: wallet, status: :pending, amount: 10)

      # Реальная подпись (Crypto::Ethereum.sign_transaction → nonce/gas/params) БЕЗ NameError:
      # build_signed_transaction возвращает { raw:, tx_hash: }, relay! разворачивает его.
      # Начисления идут на reward pool-контракт через sendReward(address,uint256),
      # а НЕ transfer (transfer на TravelFiRewards ревертит — метода нет).
      expect(Crypto::Ethereum).to receive(:encode_reward_data)
        .with(wallet.address, TokenTransactionService.to_wei(10, 18))
        .and_call_original

      # eth_sendRawTransaction реально вызывается (стаб в stub_rpc) с подписанной tx (0x)
      # → возвращает tx_hash → receipt-стаб (0x1) → confirmed. Никакого NameError.

      expect { described_class.relay!(tx) }
        .to change { tx.reload.status }.from('pending').to('confirmed')
      expect(tx.tx_hash).to eq(tx_hash)
      expect(tx.claimed).to be(true)
    end

    it 'ставит failed (НЕ confirmed) при revert-транзакции (receipt status 0x0)' do
      stub_rpc
      stub_receipt('0x0') # перекрываем success-стаб из stub_rpc
      tx = create(:token_transaction, user: user, wallet: wallet, status: :pending)

      expect { described_class.relay!(tx) }
        .to change { tx.reload.status }.from('pending').to('failed')
      expect(tx.reload.tx_hash).to be_nil
      expect(tx.reload.claimed).to be(false)
    end

    it 'ставит failed, если receipt так и не подтвердился (null → таймаут)' do
      # getTransactionReceipt всегда возвращает null (tx не найден) → ретраи до таймаута.
      stub_rpc
      stub_request(:post, rpc_url).with(body: /eth_getTransactionReceipt/)
        .to_return(json(nil))
      tx = create(:token_transaction, user: user, wallet: wallet, status: :pending)

      expect { described_class.relay!(tx) }
        .to change { tx.reload.status }.from('pending').to('failed')
    end

    it 'не вызывает eth_sendRawTransaction при ошибке подписи (нет RPC-стаба → WebMock → failed)' do
      # Стейбим только вспомогательные RPC (nonce/gas), НО НЕ eth_estimateGas:
      # estimate_gas падает → fallback DEFAULT_GAS (не ошибка). sendRaw не стейбим,
      # а sign_transaction реальный → если бы relay! не делал send — тестовый ход верный.
      stub_request(:post, rpc_url).with(body: /eth_getTransactionCount/).to_return(json('0x0'))
      stub_request(:post, rpc_url).with(body: /eth_gasPrice/).to_return(json('0x3b9aca00'))
      stub_request(:post, rpc_url).with(body: /eth_getTransactionReceipt/).to_return(json(nil))
      tx = create(:token_transaction, user: user, wallet: wallet, status: :pending)

      # WebMock запрещает реальный сетевой вызов eth_sendRawTransaction → rescue Exception → failed.
      # (WebMock::NetConnectNotAllowedError — Exception, не StandardError.)
      expect { described_class.relay!(tx) }
        .to change { tx.reload.status }.from('pending').to('failed')
    end

    it 'пропускает без OPERATOR_PRIVATE_KEY' do
      allow(ENV).to receive(:[]).with('OPERATOR_PRIVATE_KEY').and_return(nil)
      tx = create(:token_transaction, user: user, wallet: wallet, status: :pending)

      expect { described_class.relay!(tx) }.not_to change { tx.reload.status }
    end

    it 'пропускает без custodial-кошелька' do
      stub_rpc
      tx = create(:token_transaction, user: user, wallet: nil, status: :pending)

      expect { described_class.relay!(tx) }.not_to change { tx.reload.status }
    end

    it 'не дублирует уже отправленную транзакцию' do
      stub_rpc
      tx = create(:token_transaction, user: user, wallet: wallet, status: :confirmed, tx_hash: "0x#{'cd' * 32}")

      expect { described_class.relay!(tx) }.not_to change { tx.reload.tx_hash }
    end

    it 'помечает failed при ошибке RPC' do
      stub_request(:post, rpc_url).to_return(status: 500, body: '{}', headers: {})
      tx = create(:token_transaction, user: user, wallet: wallet, status: :pending)

      expect { described_class.relay!(tx) }
        .to change { tx.reload.status }.from('pending').to('failed')
    end

    it 'повторно отправляет failed-транзакцию (ретрай failed → pending → confirmed)' do
      stub_rpc
      tx = create(:token_transaction, user: user, wallet: wallet, status: :failed, claimed: false)

      expect { described_class.relay!(tx) }
        .to change { tx.reload.status }.from('failed').to('confirmed')
      expect(tx.reload.claimed).to be(true)
    end

    it 'ставит claimed=true при успешной отправке' do
      stub_rpc
      tx = create(:token_transaction, user: user, wallet: wallet, status: :pending, claimed: false)

      expect { described_class.relay!(tx) }
        .to change { tx.reload.claimed }.from(false).to(true)
    end
  end

  describe '.backfill_pending!' do
    it 'отправляет только instant-начисления (registration), vesting пропускает' do
      stub_rpc
      wallet # создать custodial-кошелёк для user (нужен backfill_pending!)
      instant_tx = create(:token_transaction, user: user, wallet: nil, status: :pending,
                                              action_key: 'registration', claimed: false)
      vesting_tx = create(:token_transaction, user: user, wallet: nil, status: :pending,
                                              action_key: 'poi_create', claimed: false)

      expect(TokenTransactionRelayJob).to receive(:perform_later).with(instant_tx.id).once
      expect(TokenTransactionRelayJob).not_to receive(:perform_later).with(vesting_tx.id)

      described_class.backfill_pending!(user)
    end
  end

  describe '.to_wei' do
    it 'переводит сумму в wei с 18 decimals' do
      expect(described_class.to_wei('1', 18)).to eq('1000000000000000000')
      expect(described_class.to_wei('0.5', 18)).to eq('500000000000000000')
    end

    it 'возвращает "0" для пустой строки' do
      expect(described_class.to_wei('', 18)).to eq('0')
    end
  end
end
