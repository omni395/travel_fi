# frozen_string_literal: true

require 'rails_helper'

#
# ContractBalanceCheckJob — unit-спек мониторинга баланса reward pool-контракта.
#
# RPC мокается через WebMock (реальная сеть не затрагивается).
#
RSpec.describe ContractBalanceCheckJob, type: :job do
  let(:admin) { create(:user, :admin, :with_setting) }
  let(:pool) { '0x0000000000000000000000000000000000000abc' }
  let(:rpc_url) { 'https://base-sepolia.drpc.org' }

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:[]).with('RPC_URL').and_return(rpc_url)
    allow(ENV).to receive(:[]).with('REWARDS_CONTRACT_ADDRESS').and_return(pool)
    allow(ENV).to receive(:[]).with('TOKEN_CONTRACT_ADDRESS').and_return(pool)
    allow(ENV).to receive(:[]).with('OPERATOR_PRIVATE_KEY').and_return("0x#{'11' * 32}")
  end

  def stub_balance(wei)
    stub_request(:post, rpc_url)
      .with(body: /eth_call/)
      .to_return(status: 200, body: { jsonrpc: '2.0', id: 1, result: wei }.to_json, headers: { 'Content-Type' => 'application/json' })
  end

  it 'шлёт алерт, когда баланс ниже critical порога' do
    admin # создаём админа, чтобы он получил уведомление
    # critical_balance из конфига = 1_000_000 TFT; ставлю баланс 500_000 TFT (в wei).
    stub_balance('0x' + (0.5e6 * 10**18).to_i.to_s(16))

    expect { described_class.perform_now }
      .to change { Noticed::Notification.where(recipient: admin).count }.by(1)
  end

  it 'не шлёт алерт, когда баланс выше warning порога' do
    admin
    # warning_balance = 10_000_000 TFT; баланс 20_000_000 TFT (выше).
    stub_balance('0x' + (20e6 * 10**18).to_i.to_s(16))

    expect { described_class.perform_now }
      .not_to change { Noticed::Notification.where(recipient: admin).count }
  end
end
