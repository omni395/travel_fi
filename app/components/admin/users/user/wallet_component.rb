# frozen_string_literal: true

#
# Admin::Users::User::WalletComponent - вкладка кошелька пользователя в админке.
#
# Отображает:
# - баланс токенов TFT (off-chain леджер)
# - реферальную информацию (кто пригласил, сколько пригласил)
# - историю транзакций (TokenTransaction) со ссылками на explorer (выжимка 4+4)
#
# @param user [User] пользователь
#
class Admin::Users::User::WalletComponent < ApplicationComponent
  def initialize(user:)
    @user = user
  end

  private

  attr_reader :user

  #
  # Последние транзакции токенов пользователя (для таблицы).
  #
  # @return [ActiveRecord::Relation] транзакции
  #
  def transactions
    user.token_transactions.ordered.limit(20)
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
  # Локализованный статус транзакции.
  #
  # @param transaction [TokenTransaction] транзакция
  # @return [String] статус
  #
  def status_label(transaction)
    t(".statuses.#{transaction.status}", default: transaction.status.humanize)
  end

  #
  # Локализованное направление движения токенов.
  #
  # @param transaction [TokenTransaction] транзакция
  # @return [String] направление
  #
  def direction_label(transaction)
    t(".directions.#{transaction.direction}", default: transaction.direction.humanize)
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

  #
  # Возвращает CSS-класс бейджа статуса транзакции.
  #
  # @param transaction [TokenTransaction] транзакция
  # @return [String] CSS-класс
  #
  def status_class(transaction)
    case transaction.status
    when "confirmed" then "bg-emerald-100 text-emerald-800"
    when "failed" then "bg-red-100 text-red-800"
    else "bg-gray-100 text-gray-800"
    end
  end
end
