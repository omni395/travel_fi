# frozen_string_literal: true

#
# ContractBalanceCheckJob — периодический мониторинг баланса reward pool-контракта.
#
# Читает пороги (TFT) из config/gamification.yml (секция pool):
#   - warning_balance  (жёлтая плашка)
#   - critical_balance (красная плашка)
# При балансе ниже порога — шлёт уведомление админам через Noticed
# (ContractBalanceNotification), чтобы интерфейс показывал жёлтую/красную плашку.
#
# Расписание — config/recurring.yml (SolidQueue Recurring).
#
class ContractBalanceCheckJob < ApplicationJob
  queue_as :default

  #
  # Выполняет проверку баланса reward pool и рассылает алерты при необходимости.
  #
  def perform
    pool = TokenTransactionService.rewards_contract_address
    return if pool.blank?

    balance_wei = TokenTransactionService.balance_of(pool)
    return if balance_wei.nil?

    balance = TokenTransactionService.wei_to_tokens(balance_wei)

    warning = GamificationService.pool_warning_balance
    critical = GamificationService.pool_critical_balance

    level =
      if balance < critical then :critical
      elsif balance < warning then :warning
      end

    return unless level

    User.with_role(:admin).find_each do |admin|
      ContractBalanceNotification.with(
        pool: pool,
        balance: balance,
        level: level,
        warning_balance: warning,
        critical_balance: critical
      ).deliver_later(admin)
    end
  rescue StandardError => e
    Rails.logger.error("ContractBalanceCheckJob error: #{e.class} #{e.message}")
  end
end
