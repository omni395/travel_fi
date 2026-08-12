# frozen_string_literal: true

require "net/http"
require "json"

#
# TokenTransactionService — единый сервис сущности TokenTransaction (журнал токенов).
#
# Отвечает за on-chain отправку начислений: серверный relay, который вызывает
# `transfer(to, amountWei)` на reward pool-контракте (TravelFiRewards) — токены
# берутся ИЗ БАЛАНСА контракта, а не минятся. Газ спонсирует оператор
# (подпись EIP-155 ключом OPERATOR_PRIVATE_KEY) → для юзера это gasless и
# без лок-периода (сразу на custodial-адрес).
#
# Флоу:
#   1. Берём custodial-адрес юзера (user.wallet.address)
#   2. Собираем calldata transfer(address,uint256) (ABI) для POOL_CONTRACT_ADDRESS
#   3. Подписываем транзакцию EIP-155 приватным ключом оператора (OPERATOR_PRIVATE_KEY)
#   4. eth_sendRawTransaction → tx_hash
#   5. Обновляем TokenTransaction через update! (PaperTrail → broadcast): tx_hash + confirmed
#
# Без OPERATOR_PRIVATE_KEY или без custodial-кошелька — транзакция пропускается
# (остаётся pending, отправится позже после появления кошелька).
#
class TokenTransactionService
  DEFAULT_GAS = 120_000
  DEFAULT_GAS_PRICE = 1_000_000_000 # 1 gwei (fallback)

  #
  # Переводит сумму токенов в wei (строка целого числа) с учётом decimals.
  #
  # @param amount [String, Numeric] сумма в токенах
  # @param decimals [Integer] количество знаков после запятой (по умолчанию 18)
  # @return [String] сумма в wei
  #
  def self.to_wei(amount, decimals = 18)
    amt = amount.to_s.strip
    return "0" if amt == ""

    require "bigdecimal"
    value = BigDecimal(amt)
    factor = BigDecimal(10) ** decimals
    (value * factor).to_i.to_s
  end

  #
  # Точка входа: отправляет начисление в сеть (идемпотентно).
  #
  # @param token_transaction [TokenTransaction] запись журнала токенов
  # @return [String, nil] tx_hash или nil (если не отправлено/ошибка)
  #
  def self.relay!(token_transaction)
    new(token_transaction).relay!
  end

  #
  # Backfill: отправляет pending-начисления юзера после появления custodial-кошелька.
  # Назначает кошелёк на транзакции (у email-регистрации welcome идёт ДО создания
  # кошелька) и ставит их в очередь на on-chain отправку.
  #
  # @param user [User] пользователь, получивший custodial-кошелёк
  #
  def self.backfill_pending!(user)
    wallet = user.wallet
    return unless wallet

    # Возвращает записи, которые можно отправить сразу: мгновенные (lock=0,
    # registration/referral_*) и уже разблокированные по лок-периоду (available).
    # Vesting-записи (ещё заблокированные) пропускаем — они ждут claim.
    user.token_transactions.where(status: :pending).where(tx_hash: nil).find_each do |tx|
      next unless tx.instant? || tx.available?

      tx.update!(wallet: wallet) if tx.wallet_id.blank?
      TokenTransactionRelayJob.perform_later(tx.id)
    end
  end

  attr_reader :token_transaction

  def initialize(token_transaction)
    @token_transaction = token_transaction
  end

  #
  # Выполняет отправку. При ошибке RPC/подписи помечает транзакцию failed
  # через update! (аудит PaperTrail), НЕ поднимая исключение (job не роняется).
  #
  # @return [String, nil] tx_hash
  #
  def relay!
    return unless operator_private_key.present?
    return if token_transaction.tx_hash.present?
    return unless %w[pending failed].include?(token_transaction.status)

    wallet = token_transaction.wallet
    return unless wallet&.address.present?

    # Ретрай после failed: сбрасываем в pending перед повторной отправкой.
    token_transaction.update!(status: :pending) if token_transaction.status == "failed"

    signed = build_signed_transaction(wallet.address)
    tx_hash = rpc("eth_sendRawTransaction", [ "0x#{signed[:raw]}" ])
    return unless tx_hash

    # Успех: confirmed + claimed=true (начисление получено). update! обновляет
    # updated_at → PaperTrail → broadcast (версии/зоны обновляются).
    token_transaction.update!(tx_hash: tx_hash, status: :confirmed, claimed: true)
    Rails.logger.info("TokenTransactionService: claimed #{token_transaction.amount} TFT to #{wallet.address} tx=#{tx_hash}")
    tx_hash
  rescue StandardError => e
    Rails.logger.error("TokenTransactionService relay! error: #{e.class} #{e.message}")
    mark_failed
    nil
  rescue Exception => e # rubocop:disable Lint/RescueException
    # Фоновая задача НЕ должна ронять worker: WebMock::NetConnectNotAllowedError
    # наследуется от Exception (не StandardError) и в тестах возникает при
    # реальном RPC-вызове (сеть запрещена). Ловим Exception, помечаем failed.
    Rails.logger.error("TokenTransactionService relay! exception: #{e.class} #{e.message}")
    mark_failed
    nil
  end

  private

  #
  # Помечает транзакцию failed с сохранением аудита (PaperTrail → broadcast).
  # Если и это падает — только лог (не роняем job).
  #
  def mark_failed
    token_transaction.update!(status: :failed) if token_transaction.persisted?
  rescue StandardError => e
    Rails.logger.error("TokenTransactionService mark_failed error: #{e.class} #{e.message}")
  end

  #
  # Строит подписанную транзакцию transfer(to, amountWei) оператором на
  # reward pool-контракт (токены берутся из его баланса). Газ спонсирует оператор.
  #
  # @param to_address [String] custodial-адрес юзера
  # @return [Hash] { raw: String, tx_hash: String }
  #
  def build_signed_transaction(to_address)
    amount_wei = self.class.to_wei(token_transaction.amount, 18)
    data = Crypto::Ethereum.encode_transfer_data(to_address, amount_wei)

    nonce = nonce_of(operator_address)
    gas_price = gas_price_for
    gas = estimate_gas(data)

    Crypto::Ethereum.sign_transaction(
      private_key_hex: operator_private_key,
      nonce: nonce,
      gas_price: gas_price,
      gas: gas,
      to: rewards_contract_address,
      value: 0,
      data: data,
      chain_id: chain_id
    )
  end

  #
  # Адрес reward-контракта TravelFiRewards, с баланса которого берутся начисления.
  # ENV REWARDS_CONTRACT_ADDRESS; fallback на сам токен.
  #
  # @return [String] адрес контракта наград
  #
  def rewards_contract_address
    self.class.rewards_contract_address
  end

  #
  # Возвращает RPC URL из ENV (читается в рантайме, чтобы ENV-стабы в тестах работали).
  #
  # @return [String, nil] URL JSON-RPC эндпоинта
  #
  def rpc_url
    self.class.rpc_url
  end

  #
  # Возвращает адрес TFT-токена из ENV (читается в рантайме).
  #
  # @return [String, nil] адрес токена
  #
  def token_address
    self.class.token_address
  end

  #
  # Возвращает приватный ключ оператора из ENV (64 hex, без 0x).
  #
  # @return [String, nil] ключ или nil
  #
  def operator_private_key
    key = ENV["OPERATOR_PRIVATE_KEY"]
    key&.sub(/\A0x/, "")
  end

  #
  # Возвращает адрес оператора (из приватного ключа, EIP-55).
  #
  # @return [String] адрес
  #
  def operator_address
    @operator_address ||= Crypto::Ethereum.address_from_private_key(operator_private_key)
  end

  #
  # Возвращает id сети (EIP-155) из ENV CHAIN_ID.
  #
  # @return [Integer] id сети
  #
  def chain_id
    (ENV["CHAIN_ID"] || "0x14a34").to_i(16)
  end

  #
  # Возвращает текущий nonce отправителя (учёт pending-транзакций в mempool).
  #
  # @param address [String] адрес отправителя
  # @return [Integer] nonce
  #
  def nonce_of(address)
    rpc("eth_getTransactionCount", [ address, "pending" ]).to_i(16)
  end

  #
  # Возвращает текущую цену газа; при сбое — fallback (1 gwei).
  #
  # @return [Integer] цена газа (wei)
  #
  # Возвращает цену газа на 15% выше текущей рыночной. Bump-запас нужен, чтобы
  # транзакция прошла в мемпул при росте цены газа (иначе legacy-подпись с ровно
  # рыночной ценой зависает в Pending и не майнится).
  #
  # @return [Integer] цена газа в wei
  #
  def gas_price_for
    base = rpc("eth_gasPrice").to_i(16)
    (base * 1.15).ceil
  rescue StandardError
    DEFAULT_GAS_PRICE
  end

  #
  # Оценивает лимит газа для вызова; при сбое — fallback.
  #
  # @param data [String] calldata
  # @return [Integer] лимит газа
  #
  def estimate_gas(data)
    rpc("eth_estimateGas", [ { from: operator_address, to: token_address, data: data }, "latest" ]).to_i(16)
  rescue StandardError
    DEFAULT_GAS
  end

  #
  # Выполняет JSON-RPC вызов через HTTP.
  #
  # @param method [String] имя метода RPC
  # @param params [Array] параметры
  # @return [Object] результат
  #
  def rpc(method, params)
    uri = URI.parse(rpc_url)
    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")

    request = Net::HTTP::Post.new(uri.path.empty? ? "/" : uri.path)
    request["Content-Type"] = "application/json"
    request.body = { jsonrpc: "2.0", method: method, params: params, id: 1 }.to_json

    parsed = JSON.parse(http.request(request).body)
    raise parsed["error"]["message"] if parsed["error"]

    parsed["result"]
  end

  class << self
    #
    # RPC URL из ENV (читается в рантайме, чтобы ENV-стабы в тестах работали).
    #
    # @return [String, nil] URL JSON-RPC эндпоинта
    #
    def rpc_url
      ENV["RPC_URL"]
    end

    #
    # Адрес TFT-токена из ENV (читается в рантайме).
    #
    # @return [String, nil] адрес токена
    #
    def token_address
      ENV["TOKEN_CONTRACT_ADDRESS"]
    end

    #
    # Адрес reward-контракта TravelFiRewards (REWARDS_CONTRACT_ADDRESS; fallback — токен).
    #
    # @return [String]
    #
    def rewards_contract_address
      ENV["REWARDS_CONTRACT_ADDRESS"].presence || token_address
    end

    #
    # Читает on-chain баланс TFT контракта (reward pool) через eth_call.
    # Возвращает баланс в token-единицах (не wei).
    #
    # @param address [String] адрес контракта (по умолчанию TravelFiRewards)
    # @return [Integer, nil] баланс в TFT или nil при ошибке RPC
    #
    def balance_of(address = rewards_contract_address)
      return nil if address.blank? || rpc_url.blank?

      data = Crypto::Ethereum.encode_balance_data(address)
      raw = new(nil).send(:rpc, "eth_call", [ { to: address, data: data }, "latest" ])
      return nil unless raw.is_a?(String)

      raw.to_i(16)
    rescue StandardError => e
      Rails.logger.error("TokenTransactionService balance_of error: #{e.class} #{e.message}")
      nil
    end

    #
    # Переводит wei в token-единицы (TFT, decimals 18).
    #
    # @param wei [Integer, String] значение в wei
    # @return [BigDecimal] значение в TFT
    #
    def wei_to_tokens(wei, decimals = 18)
      BigDecimal(wei.to_s) / (BigDecimal(10)**decimals)
    end
  end
end
