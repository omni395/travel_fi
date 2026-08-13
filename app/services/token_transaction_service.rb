# frozen_string_literal: true

require "net/http"
require "json"

#
# TokenTransactionService — единый сервис сущности TokenTransaction (журнал токенов).
#
# Отвечает за on-chain отправку начислений: серверный relay, который вызывает
# `sendReward(to, amountWei)` на reward pool-контракте TravelFiRewards
# (REWARDS_CONTRACT_ADDRESS) — токены берутся ИЗ БАЛАНСА пула, а не минятся.
# Газ спонсирует оператор (подпись EIP-155 ключом OPERATOR_PRIVATE_KEY,
# у пула OPERATOR_ROLE) → для юзера это gasless и без лок-периода.
#
# Флоу:
#   1. Берём custodial-адрес юзера (user.wallet.address)
#   2. Собираем calldata sendReward(address,uint256) (ABI) для REWARDS_CONTRACT_ADDRESS
#   3. Подписываем транзакцию EIP-155 приватным ключом оператора (OPERATOR_PRIVATE_KEY)
#   4. eth_sendRawTransaction → tx_hash
#   5. Верифицируем receipt (eth_getTransactionReceipt, status == 0x1)
#   6. Обновляем TokenTransaction через update! (PaperTrail → broadcast): tx_hash + confirmed
#
# Контракты (см. .env): TOKEN_CONTRACT_ADDRESS (TravelFiToken), REWARDS_CONTRACT_ADDRESS
# (TravelFiRewards — пул наград), CROWDSALE_CONTRACT_ADDRESS (TravelFiCrowdsale).
# Relay начислений идёт ТОЛЬКО на REWARDS; TOKEN/CROWDSALE используются другими
# потоками (mint/продажи) и relay не затрагивают.
#
# Без OPERATOR_PRIVATE_KEY или без custodial-кошелька — транзакция пропускается
# (остаётся pending, отправится позже после появления кошелька).
#
class TokenTransactionService
  DEFAULT_GAS = 120_000

  # Интервал опроса receipt (eth_getTransactionReceipt) при верификации on-chain
  # подтверждения отправленной транзакции.
  #
  # @return [Float] секунды между опросами
  #
  RECEIPT_POLL_INTERVAL = 2.0

  # Максимальное время ожидания подтверждения receipt после eth_sendRawTransaction.
  # Если за это время транзакция не получила статус (или заревертила) — failed.
  #
  # @return [Integer] секунды
  #
  RECEIPT_MAX_WAIT = 120

  #
  # Fallback цена газа для legacy транзакций (EIP-155) из ENV.
  # Конвертируется из Gwei в wei: 50 Gwei = 50_000_000_000 wei
  # Если ENV не задан → fallback 50 Gwei
  #
  # @return [Integer] цена газа в wei
  #
  def self.default_gas_price
    gwei = (ENV["GAS_PRICE_FALLBACK_GWEI"] || "50").to_i
    gwei * 1_000_000_000
  end

  #
  # Множитель для bump'а цены газа при ретрае (replacement TX в мемпуле).
  # Из ENV; fallback 1.25 (25% bump).
  #
  # @return [Float] множитель (например, 1.25)
  #
  def self.gas_price_bump_multiplier
    (ENV["GAS_PRICE_BUMP_MULTIPLIER"] || "1.25").to_f
  end

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
    # Передаём флаг is_retry=true, чтобы использовать бо́льший bump газа.
    is_retry = token_transaction.status == "failed"
    token_transaction.update!(status: :pending) if is_retry

    signed = build_signed_transaction(wallet.address, is_retry: is_retry)
    return unless signed

    # Отправляем подписанную транзакцию в сеть. Возвращается tx_hash от RPC.
    tx_hash = send_raw_transaction(signed[:raw])
    Rails.logger.info("TokenTransactionService: sent raw tx=#{tx_hash}")

    # Верифицируем on-chain подтверждение: только receipt со status 0x1 (Success)
    # считается успешным начислением. Revert/таймаут → failed.
    unless wait_for_receipt(tx_hash)
      Rails.logger.error("TokenTransactionService: tx #{tx_hash} not confirmed (reverted or timeout)")
      mark_failed
      return nil
    end

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
  # @param is_retry [Boolean] является ли это ретраем failed транзакции (для большего bump)
  # @return [Hash] { raw: String, tx_hash: String }
  #
  def build_signed_transaction(to_address, is_retry: false)
    amount_wei = self.class.to_wei(token_transaction.amount, 18)
    # Relayer-пул (TravelFiRewards) выдаёт TFT из своего баланса через sendReward(address,uint256).
    # (transfer(address,uint256) на пул ревертит — у TravelFiRewards такого метода нет.)
    data = Crypto::Ethereum.encode_reward_data(to_address, amount_wei)

    nonce = nonce_of(operator_address)
    gas_price = gas_price_for(is_retry: is_retry)
    gas = estimate_gas(data)

    # Логирование реальных параметров перед подписью
    gas_price_gwei = gas_price.to_i / 1_000_000_000.0
    Rails.logger.info("TokenTransactionService build_signed_transaction: tx_id=#{token_transaction.id}, nonce=#{nonce}, gasPrice=#{gas_price_gwei} Gwei (#{gas_price} wei), gas=#{gas}, is_retry=#{is_retry}")

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
  # Отправляет подписанную сырую транзакцию в сеть через eth_sendRawTransaction.
  #
  # @param raw_tx [String] подписанная RLP-транзакция (hex, без 0x)
  # @return [String] tx_hash от RPC (0x + 64 hex)
  #
  def send_raw_transaction(raw_tx)
    rpc("eth_sendRawTransaction", [ "0x#{raw_tx}" ])
  end

  #
  # Верифицирует on-chain подтверждение отправленной транзакции.
  # Опрашивает eth_getTransactionReceipt до появления receipt с ненулевым
  # blockNumber; успехом считается только status == "0x1" (Success). Revert
  # (status "0x0") или истечение таймаута → false (транзакция НЕ засчитывается).
  #
  # @param tx_hash [String] хэш отправленной транзакции (0x + 64 hex)
  # @return [Boolean] true если транзакция подтверждена успешно
  #
  def wait_for_receipt(tx_hash)
    deadline = Time.now + self.class::RECEIPT_MAX_WAIT

    loop do
      receipt = rpc("eth_getTransactionReceipt", [ tx_hash ])
      # Ранние RPC возвращают null → ждём следующие блоки.
      unless receipt.nil? || receipt["blockNumber"].nil? || receipt["blockNumber"].empty?
        return receipt["status"].to_s == "0x1"
      end

      return false if Time.now >= deadline

      sleep self.class::RECEIPT_POLL_INTERVAL
    end
  rescue StandardError => e
    Rails.logger.error("TokenTransactionService wait_for_receipt error: #{e.class} #{e.message}")
    false
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
  # Возвращает безопасный nonce отправителя.
  # Использует максимум между "latest" (подтвержденные TX) и "pending" (в мемпуле),
  # чтобы избежать "nonce too low" ошибки при рассинхронизме RPC.
  #
  # @param address [String] адрес отправителя
  # @return [Integer] nonce
  #
  def nonce_of(address)
    latest = rpc("eth_getTransactionCount", [ address, "latest" ]).to_i(16)
    pending = rpc("eth_getTransactionCount", [ address, "pending" ]).to_i(16)

    # Берем больший nonce для безопасности (гарантирует >= всех обработанных TX)
    safe_nonce = [ latest, pending ].max
    Rails.logger.info("TokenTransactionService nonce_of(#{address}): latest=#{latest}, pending=#{pending}, using=#{safe_nonce}")
    safe_nonce
  rescue StandardError => e
    Rails.logger.error("TokenTransactionService nonce_of error: #{e.class} #{e.message}")
    # Fallback: вернуть хотя бы latest если что-то упало
    rpc("eth_getTransactionCount", [ address, "latest" ]).to_i(16)
  end

  #
  # Возвращает текущую цену газа с bump'ом. При ошибке RPC — fallback из ENV.
  #
  # Bump-запас нужен, чтобы транзакция прошла в мемпул при росте цены газа
  # (иначе legacy-подпись с ровно рыночной ценой зависает в Pending и не майнится).
  #
  # При ретрае (replacement TX) использует бо́льший bump (GAS_PRICE_BUMP_MULTIPLIER),
  # потому что мемпул требует цены выше оригинальной для замены.
  #
  # @param is_retry [Boolean] является ли это ретраем failed транзакции
  # @return [Integer] цена газа в wei
  #
  def gas_price_for(is_retry: false)
    base = rpc("eth_gasPrice").to_i(16)
    bump = is_retry ? self.class.gas_price_bump_multiplier : 1.15
    result = (base * bump).ceil

    result_gwei = result / 1_000_000_000.0
    Rails.logger.info("TokenTransactionService gas_price_for: base=#{base / 1_000_000_000.0} Gwei, bump=#{bump}, result=#{result_gwei} Gwei, is_retry=#{is_retry}")
    result
  rescue StandardError => e
    # Fallback: используем параметр из ENV, с применением bump если ретрай
    fallback = self.class.default_gas_price
    bump = is_retry ? self.class.gas_price_bump_multiplier : 1.0
    result = is_retry ? (fallback * self.class.gas_price_bump_multiplier).ceil : fallback

    result_gwei = result / 1_000_000_000.0
    fallback_gwei = fallback / 1_000_000_000.0
    Rails.logger.warn("TokenTransactionService gas_price_for FALLBACK: error=#{e.class}, fallback=#{fallback_gwei} Gwei, bump=#{bump}, result=#{result_gwei} Gwei, is_retry=#{is_retry}")
    result
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
