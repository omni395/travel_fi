# frozen_string_literal: true

require 'rails_helper'

#
# WalletService — создание скрытого custodial-кошелька.
# Проверки: валидный адрес, шифрование private key, идемпотентность, денормализация на юзере.
#
RSpec.describe WalletService do
  let!(:user) { create(:user) }

  describe '.create_hidden_wallet' do
    it 'создаёт кошелёк с валидным EIP-55 адресом и chain_id' do
      wallet = described_class.create_hidden_wallet(user: user)

      expect(wallet).to be_persisted
      expect(wallet.address).to match(/\A0x[0-9a-fA-F]{40}\z/)
      expect(wallet.chain_id).to be_present
      expect(wallet.encrypted_private_key).to be_present
      # Приватный ключ хранится зашифрованным (не в открытом виде).
      expect(wallet.encrypted_private_key).not_to include(wallet.private_key)
    end

    it 'денормализует адрес в users.wallet_address' do
      wallet = described_class.create_hidden_wallet(user: user)

      expect(user.reload.wallet_address).to eq(wallet.address)
    end

    it 'идемпотентен: повторный вызов не создаёт второй кошелёк' do
      described_class.create_hidden_wallet(user: user)

      expect { described_class.create_hidden_wallet(user: user) }
        .not_to change { user.reload.wallet }

      expect(user.wallet).to be_present
    end

    it 'расшифровывает private key через decrypt_private_key' do
      wallet = described_class.create_hidden_wallet(user: user)

      expect(described_class.decrypt_private_key(wallet)).to eq(wallet.private_key)
    end
  end
end
