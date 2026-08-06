# frozen_string_literal: true

require 'rails_helper'

#
# Wallet — unit-тесты модели кошелька.
#
RSpec.describe Wallet, type: :model do
  let(:user) { create(:user) }

  describe 'валидации' do
    it 'требует address и chain_id' do
      expect(Wallet.new(user: user)).not_to be_valid
      expect(Wallet.new(user: user, address: '0x123')).not_to be_valid
    end

    it 'custodial требует encrypted_private_key' do
      wallet = Wallet.new(user: user, address: '0xabc', chain_id: 8453, kind: :custodial)
      expect(wallet).not_to be_valid
    end

    it 'external не требует private key' do
      wallet = Wallet.new(user: user, address: '0xabc', chain_id: 8453, kind: :external)
      expect(wallet).to be_valid
    end
  end

  describe 'WalletService.create_hidden_wallet' do
    it 'создаёт custodial-кошелёк с зашифрованным ключом' do
      wallet = WalletService.create_hidden_wallet(user: user)

      expect(wallet).to be_custodial
      expect(wallet.address).to be_present
      expect(wallet.chain_id).to be_present
      expect(wallet.encrypted_private_key).to be_present
    end
  end
end
