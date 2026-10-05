# frozen_string_literal: true

#
# Users::ProfileComponent - отображает профиль пользователя
#
# Показывает аватар, имя, email, статус, репутацию, points, badges, роли
# Используется на страницах профилей и в админ-панели
#
# @param user [User] пользователь для отображения
#
class Users::ProfileComponent < ApplicationComponent
  def initialize(user:)
    @user = user
  end

  private

  attr_reader :user

  #
  # Возвращает цвет для Ui::BadgeComponent в зависимости от статуса
  #
  # @return [Symbol] цвет (:success, :warning, :error, :gray, :primary)
  #
  def status_color
    case user.status
    when "active" then :success
    when "pending_verification" then :warning
    when "suspended" then :error
    when "banned" then :error
    when "deleted" then :gray
    else :primary
    end
  end

  #
  # Разблокированные по лок-периоду, ещё не забранные начисления (unclaimed.available).
  # Spendable — это именно то, что пользователь МОЖЕТ забрать (claim), а не уже
  # забранное. Мгновенные начисления (registration / referral_bonus_new_user)
  # доступны сразу, vesting — после истечения lock-периода.
  #
  # @return [ActiveRecord::Relation]
  #
  def available_transactions
    user.token_transactions.unclaimed.available
  end

  #
  # Заблокированные по vesting-лок-периоду, ещё не забранные начисления
  # (unclaimed.locked). Мгновенные (lock=0) сюда не попадают.
  #
  # @return [ActiveRecord::Relation]
  #
  def locked_transactions
    user.token_transactions.unclaimed.locked
  end

  #
  # Забранные on-chain начисления (claimed=true) — фактический баланс TFT.
  #
  # @return [ActiveRecord::Relation]
  #
  def claimed_transactions
    user.token_transactions.claimed
  end

  #
  # Сумма доступных к клейму (Spendable) токенов.
  #
  # @return [BigDecimal]
  #
  def available_amount
    available_transactions.sum(:amount)
  end

  #
  # Сумма заблокированных токенов.
  #
  # @return [BigDecimal]
  #
  def locked_amount
    locked_transactions.sum(:amount)
  end

  #
  # Сумма забранных on-chain токенов (фактический баланс TFT).
  #
  # @return [BigDecimal]
  #
  def claimed_amount
    claimed_transactions.sum(:amount)
  end

  #
  # Есть ли что-то доступное к получению (показывать claim-кнопку).
  #
  # @return [Boolean]
  #
  def available?
    user.token_transactions.unclaimed.available.exists?
  end

  #
  # Форматирует сумму токенов без лишних нулей (10.0 → "10").
  #
  # @param amount [Numeric] сумма
  # @return [String]
  #
  def format_amount(amount)
    helpers.number_with_precision(amount, precision: 2, strip_insignificant_zeros: true)
  end

  #
  # Проверяет может ли текущий пользователь редактировать профиль
  #
  def can_edit_profile?
    helpers.user_signed_in? && (helpers.current_user == user || helpers.policy(user).edit?)
  end
end
