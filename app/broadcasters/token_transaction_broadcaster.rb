# frozen_string_literal: true

#
# TokenTransactionBroadcaster - отправляет live-обновления при создании
# записи журнала токенов (TokenTransaction) через CableReady.
#
# Ответственность:
# 1. Обновляет вкладку Wallet в админке (AdminChannel): баланс + история
#    транзакций + реферальная инфо (inner_html [data-admin-user-wallet]).
# 2. Обновляет историю начислений в профиле юзера (user_N): inner_html
#    [data-user-rewards].
# 3. Обновляет баланс в профиле юзера (user_N): inner_html [data-user-profile-id].
#
# Использование:
#   TokenTransactionBroadcaster.call(token_transaction: tx)
#
class TokenTransactionBroadcaster
  include CableReady::Broadcaster

  #
  # Точка входа: рассылает обновления для созданной транзакции.
  #
  # @param token_transaction [TokenTransaction] запись журнала токенов
  #
  def self.call(token_transaction:)
    new(token_transaction: token_transaction).broadcast
  end

  attr_reader :token_transaction

  def initialize(token_transaction:)
    @token_transaction = token_transaction
  end

  #
  # Выполняет broadcast обновлений. Каждая зона в rescue: сбой одной не роняет остальные.
  #
  def broadcast
    user = token_transaction.user

    # 1. Админка: вкладка Wallet (баланс + история + реферальная инфо).
    admin_wallet_html = render_admin_wallet(user)
    if admin_wallet_html.present?
      cable_ready["AdminChannel"].inner_html(
        selector: "[data-admin-user-wallet]",
        html: admin_wallet_html
      )
    end

    # 2. Профиль юзера: история начислений.
    rewards_html = render_user_rewards(user)
    if rewards_html.present?
      cable_ready["user_#{user.id}"].inner_html(
        selector: "[data-user-rewards]",
        html: rewards_html
      )
    end

    # 3. Профиль юзера: актуальный баланс.
    profile_html = render_profile(user)
    if profile_html.present?
      cable_ready["user_#{user.id}"].inner_html(
        selector: "[data-user-profile-id='#{user.id}']",
        html: profile_html
      )
    end

    cable_ready.broadcast
  rescue StandardError => e
    Rails.logger.error("TokenTransactionBroadcaster error: #{e.class} #{e.message}")
  end

  private

  #
  # Рендерит компонент вкладки Wallet админки для юзера.
  #
  # @param user [User] пользователь
  # @return [String] HTML вкладки
  #
  def render_admin_wallet(user)
    component = Admin::Users::User::WalletComponent.new(user: user)
    I18n.with_locale(I18n.default_locale) do
      ApplicationController.render(component, layout: false)
    end
  rescue StandardError => e
    Rails.logger.error("TokenTransactionBroadcaster render_admin_wallet: #{e.class} #{e.message}")
    ""
  end

  #
  # Рендерит компонент истории начислений профиля юзера.
  #
  # @param user [User] пользователь
  # @return [String] HTML истории начислений
  #
  def render_user_rewards(user)
    component = Users::RewardsComponent.new(user: user)
    I18n.with_locale(I18n.default_locale) do
      ApplicationController.render(component, layout: false)
    end
  rescue StandardError => e
    Rails.logger.error("TokenTransactionBroadcaster render_user_rewards: #{e.class} #{e.message}")
    ""
  end

  #
  # Рендерит компонент профиля юзера (баланс TFT).
  #
  # @param user [User] пользователь
  # @return [String] HTML профиля
  #
  def render_profile(user)
    component = Users::ProfileComponent.new(user: user)
    I18n.with_locale(I18n.default_locale) do
      ApplicationController.render(component, layout: false)
    end
  rescue StandardError => e
    Rails.logger.error("TokenTransactionBroadcaster render_profile: #{e.class} #{e.message}")
    ""
  end
end
