# frozen_string_literal: true

require "zlib"

#
# TokenTransactionRelayJob — асинхронная on-chain отправка начислений TFT
# (SolidQueue). Вызывается после создания TokenTransaction и при backfill
# (после появления custodial-кошелька).
#
# Сериализация по оператору: все начисления подписываются одним ключом
# (OPERATOR_PRIVATE_KEY), поэтому их on-chain отправка выполняется строго
# по очереди (concurrency to: 1). Иначе параллельные relay берут одинаковый
# nonce → конфликт в мемпуле → одна tx Confirmed, вторая Failed, третья Pending.
#
class TokenTransactionRelayJob < ApplicationJob
  queue_as :default

  # Единый ключ сериализации для всех relay-задач (оператор один). Обработка
  # одного оператора — строго последовательна, nonce инкрементируется корректно.
  limits_concurrency key: "token-relay-operator", to: 1, on_conflict: :block

  #
  # Отправляет начисление в сеть через TokenTransactionService.
  #
  # Использует advisory_lock на уровне БД для гарантированной последовательности:
  # все relay-операции выполняются строго по очереди (нет race condition на nonce).
  #
  # @param token_transaction_id [Integer] ID записи журнала токенов
  #
  def perform(token_transaction_id)
    transaction = TokenTransaction.find_by(id: token_transaction_id)
    return unless transaction

    lock_id = Zlib.crc32("token-relay-operator")
    Rails.logger.info("TokenTransactionRelayJob: waiting for advisory lock (tx_id=#{token_transaction_id})")

    # БД-блокировка: только одна Job за раз может войти в этот блок
    # (гарантирует последовательный nonce без конфликтов в мемпуле)
    ActiveRecord::Base.connection.execute("SELECT pg_advisory_lock(#{lock_id})")
    begin
      Rails.logger.info("TokenTransactionRelayJob: acquired lock (tx_id=#{token_transaction_id})")
      TokenTransactionService.relay!(transaction)
    ensure
      ActiveRecord::Base.connection.execute("SELECT pg_advisory_unlock(#{lock_id})")
      Rails.logger.info("TokenTransactionRelayJob: released lock (tx_id=#{token_transaction_id})")
    end
  end
end
