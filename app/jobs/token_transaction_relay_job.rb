# frozen_string_literal: true

#
# TokenTransactionRelayJob — асинхронная on-chain отправка начислений TFT
# (SolidQueue). Вызывается после создания TokenTransaction и при backfill
# (после появления custodial-кошелька).
#
class TokenTransactionRelayJob < ApplicationJob
  queue_as :default

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
