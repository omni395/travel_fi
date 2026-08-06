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
end
