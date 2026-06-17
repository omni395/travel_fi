# frozen_string_literal: true

#
# Admin::Users::User::WalletComponent - компонент кошелька пользователя
#
# Отображает информацию о кошельке пользователя (заглушка)
#
# @param user [User] пользователь
#
class Admin::Users::User::WalletComponent < ApplicationComponent
  def initialize(user:)
    @user = user
  end

  private

  attr_reader :user
end
