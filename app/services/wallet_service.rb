# frozen_string_literal: true

#
# WalletService — создание и расшифровка custodial-кошельков.
#
# Приватный ключ шифруется ActiveSupport::MessageEncryptor (AES-256-GCM).
# Ключ шифрования: ENV['WALLET_ENCRYPTION_KEY'] (64 hex) или дериват от secret_key_base.
#
class WalletService
  class << self
    #
    # Создаёт скрытый custodial-кошелёк для пользователя (идемпотентно).
    # Адрес денормализуется в users.wallet_address.
    #
    # @param user [User] пользователь
    # @param chain_id [String, nil] id сети (по умолчанию из ENV CHAIN_ID)
    # @return [Wallet] кошелёк
    #
    def create_hidden_wallet(user:, chain_id: nil)
      existing = user.wallets.custodial.first
      return existing if existing

      private_key, address = Crypto::Ethereum.generate_keypair

      wallet = user.wallets.create!(
        address: address,
        chain_id: chain_id || default_chain_id,
        encrypted_private_key: encrypt(private_key),
        kind: :custodial
      )

      # Денормализация основного адреса на юзере (для быстрого отображения).
      user.update!(wallet_address: address)

      UserAuditLogger.log_wallet_added(user)
      wallet
    end

    #
    # Расшифровывает приватный ключ custodial-кошелька.
    #
    # @param wallet [Wallet] кошелёк
    # @return [String] приватный ключ (32 байта)
    #
    def decrypt_private_key(wallet)
      decrypt(wallet.encrypted_private_key)
    end

    private

    #
    # Возвращает id сети по умолчанию из ENV (CHAIN_ID, например 0x14a34 → 84532).
    #
    # @return [String] id сети
    #
    def default_chain_id
      (ENV['CHAIN_ID'] || '0x14a34').to_i(16).to_s
    end

    #
    # Шифрует приватный ключ.
    #
    # @param plaintext [String] открытый текст
    # @return [String] шифротекст
    #
    def encrypt(private_key_bytes)
      # Приватный ключ сериализуем в hex (ASCII) — бинарные байты не проходят JSON в MessageEncryptor.
      encryptor.encrypt_and_sign(private_key_bytes.unpack1('H*'))
    end

    #
    # Расшифровывает приватный ключ.
    #
    # @param ciphertext [String] шифротекст
    # @return [String] приватный ключ в hex (64 символа)
    #
    def decrypt(ciphertext)
      encryptor.decrypt_and_verify(ciphertext)
    end

    #
    # MessageEncryptor для private key кошельков.
    #
    # @return [ActiveSupport::MessageEncryptor]
    #
    def encryptor
      @encryptor ||= ActiveSupport::MessageEncryptor.new(encryption_key)
    end

    #
    # Ключ шифрования (32 байта): ENV['WALLET_ENCRYPTION_KEY'] (64 hex) или
    # SHA-256 дериват от Rails.application.secret_key_base.
    #
    # @return [String] 32-байтовый ключ
    #
    def encryption_key
      key_hex = ENV['WALLET_ENCRYPTION_KEY']
      return [key_hex].pack('H*') if key_hex.present?

      Digest::SHA256.digest(Rails.application.secret_key_base)
    end
  end
end
