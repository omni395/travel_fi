# frozen_string_literal: true

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
  # @param token_transaction_id [Integer] ID записи журнала токенов
  #
  def perform(token_transaction_id)
    transaction = TokenTransaction.find_by(id: token_transaction_id)
    return unless transaction

    TokenTransactionService.relay!(transaction)
  end
end
