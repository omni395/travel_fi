# frozen_string_literal: true

require 'rails_helper'

#
# Gamification — начисление токенов TFT и отображение баланса в профиле.
# А получает токены (GamificationService.award!) → профиль показывает баланс TFT.
#
RSpec.describe 'Gamification (начисления токенов → профиль)', type: :system do
  let!(:user) { create(:user, :with_setting) }

  it 'А получает токены за регистрацию → профиль показывает баланс' do
    GamificationService.award!(:registration, user)

    browser_a do
      sign_in_via_ui(user)
      visit user_path(id: user)
      wait_for_selector("[data-user-profile-id='#{user.id}']")
      expect(page).to have_content(user.reload.token_balance.to_s)
    end

    expect(user.token_balance).to be > 0
  end
end
