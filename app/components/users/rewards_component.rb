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
  # Разблокированные по лок-периоду, ещё не забранные начисления юзера.
  #
  # @return [ActiveRecord::Relation] available-начисления
  #
  def available_transactions
    user.token_transactions.unclaimed.available
  end

  #
  # Заблокированные по лок-периоду начисления юзера.
  #
  # @return [ActiveRecord::Relation] locked-начисления
  #
  def locked_transactions
    user.token_transactions.unclaimed.locked
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
  #
  # @return [Boolean]
  #
  def available?
    available_transactions.exists?
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
