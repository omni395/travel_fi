# frozen_string_literal: true

#
# TokenTransactionRetryJob — периодический авто-ретрай on-chain отправки для
# начислений, упавших на relay (status: failed).
#
# Когда relay не смог отправить начисление (например, временный сбой RPC или
# газа), транзакция помечается failed и off-chain токены остаются "зависшими" —
# начисление не доходит до блокчейна. Этот джоб периодически находит такие записи
# и переставляет их в очередь relay, чтобы отправить повторно (с корректным,
# уже освободившимся nonce — relay сериализуется по оператору).
#
# Фильтры:
#   - только status: failed с пустым tx_hash (ещё не отправленные on-chain);
#   - only мгновенные (instant) и доступные по лок-периоду (available) —
#     vesting-начисления, ещё не разблокированные, пропускаются (они ждут claim).
#
# Расписание — config/recurring.yml (SolidQueue Recurring).
#
class TokenTransactionRetryJob < ApplicationJob
  queue_as :default

  #
  # Переотправляет упавшие начисления, ставя relay-задачу для каждой в очередь.
  #
  def perform
    retried = 0

    TokenTransaction.where(status: :failed, tx_hash: nil).find_each do |tx|
      next unless tx.instant? || tx.available?

      TokenTransactionRelayJob.perform_later(tx.id)
      retried += 1
    end

    Rails.logger.info("TokenTransactionRetryJob: enqueued #{retried} failed relays") if retried.positive?
  rescue StandardError => e
    Rails.logger.error("TokenTransactionRetryJob error: #{e.class} #{e.message}")
  end
end
