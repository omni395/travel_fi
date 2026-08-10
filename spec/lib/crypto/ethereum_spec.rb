# frozen_string_literal: true

require 'rails_helper'

#
# Crypto::Ethereum — криптографический модуль для Ethereum-адресов.
# Проверяется по известным тест-векторам (keccak256, EIP-55 адрес из приватного ключа).
#
RSpec.describe Crypto::Ethereum do
  describe '.keccak256' do
    it 'совпадает с эталонным вектором для пустой строки' do
      # Известный вектор: keccak256("") 
      expect(described_class.keccak256('')).to eq(
        'c5d2460186f7233c927e7db2dcc703c0e500b653ca82273b7bfad8045d85a470'
      )
    end
  end

  describe '.address_from_private_key' do
    it 'возвращает EIP-55 адрес для приватного ключа 0x00..01 (эталонный вектор)' do
      # Известная пара: privkey = 1 → address = 0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf
      priv = '0000000000000000000000000000000000000000000000000000000000000001'
      expect(described_class.address_from_private_key(priv)).to eq(
        '0x7E5F4552091A69125d5DfCb7b8C2659029395Bdf'
      )
    end
  end

  describe '.generate_keypair' do
    it 'возвращает 32-байтовый приватный ключ и валидный EIP-55 адрес' do
      private_key, address = described_class.generate_keypair

      expect(private_key.bytesize).to eq(32)
      expect(address).to match(/\A0x[0-9a-fA-F]{40}\z/)
      # Адрес детерминирован из приватного ключа.
      expect(described_class.address_from_private_key(private_key.unpack1('H*'))).to eq(address)
    end
  end

  describe '.rlp_encode' do
    it 'соответствует эталонным RLP-векторам' do
      expect(described_class.rlp_encode('dog')).to eq("\x83dog".b)
      expect(described_class.rlp_encode([])).to eq("\xc0".b)
      expect(described_class.rlp_encode([ 1, 2, 3 ])).to eq("\xc3\x01\x02\x03".b)
      expect(described_class.rlp_encode(0)).to eq("\x80".b)
      expect(described_class.rlp_encode(127)).to eq("\x7f".b)
      expect(described_class.rlp_encode(128)).to eq("\x81\x80".b)
    end
  end

  describe '.encode_mint_data' do
    it 'формирует calldata mint(address,uint256) с selector и 32-байтовыми полями' do
      data = described_class.encode_mint_data('0x0000000000000000000000000000000000000001', 10)

      expect(data).to start_with('0x')
      # selector mint(address,uint256) = 40c10f19 + 64 + 64 hex символа.
      expect(data.length).to eq(2 + 8 + 64 + 64)
      expect(data[0, 10]).to eq('0x40c10f19')
    end
  end

  describe '.sign_transaction' do
    it 'подписывает EIP-155 транзакцию и возвращает raw + tx_hash' do
      priv = '0000000000000000000000000000000000000000000000000000000000000001'
      signed = described_class.sign_transaction(
        private_key_hex: priv,
        nonce: 0,
        gas_price: 1,
        gas: 21_000,
        to: '0x0000000000000000000000000000000000000001',
        value: 0,
        data: '0x',
        chain_id: 1
      )

      expect(signed[:raw]).to match(/\A[0-9a-f]+\z/)
      expect(signed[:tx_hash]).to match(/\A0x[0-9a-f]{64}\z/)
    end
  end
end
