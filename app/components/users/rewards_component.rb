# frozen_string_literal: true

#
# Users::RewardsComponent - история начислений токенов TFT в профиле юзера.
#
# Показывает последние записи журнала движения токенов (TokenTransaction):
# дата, тип начисления (action_key), сумма (+N TFT).
#
# @param user [User] пользователь
#
class Users::RewardsComponent < ApplicationComponent
  def initialize(user:)
    @user = user
  end

  private

  attr_reader :user

  #
  # Последние транзакции токенов пользователя.
  #
  # @return [ActiveRecord::Relation] транзакции
  #
  def transactions
    user.token_transactions.ordered.limit(20)
  end

  #
  # Разблокированные (доступные к трате) начисления юзера. Включает мгновенные
  # (lock=0) и vesting-разблокированные, независимо от on-chain статуса claimed
  # (relay мог уже отправить токены на кошелёк — они всё равно доступны к трате).
  # claim-кнопка (available?) при этом опирается на ещё незабранные начисления.
  #
  # @return [ActiveRecord::Relation] available-начисления
  #
  def available_transactions
    user.token_transactions.available_all
  end

  #
  # Заблокированные по vesting-лок-периоду начисления юзера (не разблокированы).
  # Мгновенные (lock=0) сюда не попадают. Независимо от on-chain статуса claimed.
  #
  # @return [ActiveRecord::Relation] locked-начисления
  #
  def locked_transactions
    user.token_transactions.locked_all
  end

  #
  # Сумма разблокированных (доступных к получению) токенов.
  #
  # @return [BigDecimal] доступная сумма
  #
  def available_amount
    available_transactions.sum(:amount)
  end

  #
  # Сумма заблокированных (ещё не разблокированных) токенов.
  #
  # @return [BigDecimal] заблокированная сумма
  #
  def locked_amount
    locked_transactions.sum(:amount)
  end

  #
  # Есть ли что-то доступное к получению (показывать кнопку claim).
  # Опирается на ЕЩЁ НЕ ЗАБРАННЫЕ (unclaimed) разблокированные начисления:
  # если relay уже отправил токены on-chain (claimed=true), кнопка не нужна.
  #
  # @return [Boolean]
  #
  def available?
    user.token_transactions.unclaimed.available.exists?
  end

  #
  # Локализованная подпись типа начисления (action_key).
  #
  # @param transaction [TokenTransaction] транзакция
  # @return [String] подпись
  #
  def action_key_label(transaction)
    t(".action_keys.#{transaction.action_key}", default: transaction.action_key.humanize)
  end

  #
  # Форматирует сумму токенов без лишних нулей (10.0 → "10").
  #
  # @param amount [Numeric] сумма
  # @return [String] отформатированная сумма
  #
  def format_amount(amount)
    helpers.number_with_precision(amount, precision: 2, strip_insignificant_zeros: true)
  end
end
