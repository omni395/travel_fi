# frozen_string_literal: true

#
# WalletService — создание и расшифровка custodial-кошельков.
#
# Приватный ключ шифруется ActiveSupport::MessageEncryptor (AES-256-GCM).
# Ключ шифрования: ENV['WALLET_ENCRYPTION_KEY'] (64 hex) или дериват от secret_key_base.
#
class WalletService
  class ChallengeExpired < StandardError; end

  class << self
    #
    # Builds a short-lived proof-of-ownership challenge for an external wallet.
    #
    # @param address [String] wallet address supplied by the client
    # @param base_url [String] application origin included in the signed message
    # @return [Hash] challenge state and response fields
    #
    def build_external_wallet_challenge(address:, base_url:)
      address = normalize_external_address!(address)
      chain_id = configured_chain_id
      issued_at = Time.current
      expires_at = issued_at + 5.minutes
      message = [
        "TravelFi wallet ownership verification",
        "URI: #{base_url}",
        "Version: 1",
        "Chain ID: #{chain_id}",
        "Nonce: #{SecureRandom.hex(16)}",
        "Issued At: #{issued_at.iso8601}",
        "Expiration Time: #{expires_at.iso8601}"
      ].join("\n")

      {
        challenge: {
          "address" => address.downcase,
          "chain_id" => chain_id,
          "message" => message,
          "expires_at" => expires_at.to_i
        },
        message: message,
        chain_id: chain_id
      }
    end

    #
    # Verifies an external wallet's challenge and atomically replaces its linked wallet.
    #
    # @param user [User] wallet owner
    # @param challenge [Hash] one-time challenge from the user's session
    # @param signature [String] personal_sign signature
    # @return [Wallet] linked external wallet
    #
    def connect_external!(user:, challenge:, signature:)
      raise ChallengeExpired unless valid_external_wallet_challenge?(challenge)

      recovered_address = Crypto::Ethereum.recover_personal_signer(
        message: challenge.fetch("message"),
        signature: signature
      )
      unless recovered_address.casecmp?(challenge.fetch("address"))
        raise ArgumentError, "Wallet signature does not match challenge"
      end

      user.with_lock do
        wallet = user.wallets.external.find_by(address: recovered_address)
        next wallet if wallet

        user.wallets.external.where.not(address: recovered_address).destroy_all
        user.wallets.create!(
          address: recovered_address,
          chain_id: challenge.fetch("chain_id"),
          kind: :external
        )
      end
    end

    #
    # Removes linked external wallets while preserving the custodial wallet.
    #
    # @param user [User] wallet owner
    # @return [void]
    #
    def disconnect_external!(user:)
      user.wallets.external.destroy_all
    end

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
    # Выбирает адрес для выдачи наград: подключённый внешний кошелёк имеет
    # приоритет, иначе используется custodial. При необходимости создаёт его.
    #
    # @param user [User] получатель наград
    # @param create_if_missing [Boolean] создать custodial, если кошельков нет
    # @return [Wallet, nil]
    #
    def reward_wallet(user:, create_if_missing: false)
      user.wallets.external.first ||
        user.wallet ||
        (create_hidden_wallet(user: user) if create_if_missing)
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
    # Validates and normalizes an externally supplied EVM address.
    #
    # @param value [String] address
    # @return [String] validated address
    #
    def normalize_external_address!(value)
      address = value.to_s
      raise ArgumentError, "Invalid Ethereum address" unless address.match?(/\A0x[0-9a-fA-F]{40}\z/)

      address
    end

    #
    # Reads and validates the configured EVM chain id.
    #
    # @return [String] decimal chain id
    #
    def configured_chain_id
      Integer(ENV["CHAIN_ID"].presence || "0x14a34", 0).to_s
    rescue ArgumentError
      raise ArgumentError, "Invalid configured chain id"
    end

    #
    # Checks that a challenge is current and bound to the configured network.
    #
    # @param challenge [Hash, nil] session challenge
    # @return [Boolean]
    #
    def valid_external_wallet_challenge?(challenge)
      challenge.is_a?(Hash) &&
        challenge["expires_at"].to_i > Time.current.to_i &&
        challenge["chain_id"] == configured_chain_id
    end

    #
    # Возвращает id сети по умолчанию из ENV (CHAIN_ID, например 0x14a34 → 84532).
    #
    # @return [String] id сети
    #
    def default_chain_id
      (ENV["CHAIN_ID"] || "0x14a34").to_i(16).to_s
    end

    #
    # Шифрует приватный ключ.
    #
    # @param plaintext [String] открытый текст
    # @return [String] шифротекст
    #
    def encrypt(private_key_bytes)
      # Приватный ключ сериализуем в hex (ASCII) — бинарные байты не проходят JSON в MessageEncryptor.
      encryptor.encrypt_and_sign(private_key_bytes.unpack1("H*"))
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
      key_hex = ENV["WALLET_ENCRYPTION_KEY"]
      return [ key_hex ].pack("H*") if key_hex.present?

      Digest::SHA256.digest(Rails.application.secret_key_base)
    end
  end
end
