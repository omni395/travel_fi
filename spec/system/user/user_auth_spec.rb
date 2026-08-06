# frozen_string_literal: true

require 'rails_helper'

#
# Auth — регистрация и видимость нового юзера в админке (браузер А → браузер Б).
# А регистрируется через UI (Devise) → админ Б видит нового юзера в списке.
#
RSpec.describe 'Auth (браузер А → браузер Б)', type: :system do
  let!(:admin_b) { create(:user, :admin, :with_setting) }

  it 'А регистрируется → админ Б видит нового пользователя' do
    browser_a do
      visit new_user_registration_path
      fill_in 'user[name]', with: 'New Traveler'
      fill_in 'user[email]', with: 'new_traveler@example.com'
      fill_in 'user[password]', with: 'password123'
      fill_in 'user[password_confirmation]', with: 'password123'
      # Кнопка регистрации рендерится Ui::BtnComponent → <button type="submit">
      find("button[type='submit']", match: :first).click
      # После регистрации Devise логинит А — он на главной/карте
      expect(page).to have_current_path(/pois|sign_in/)
    end

    browser_b do
      sign_in_via_ui(admin_b)
      visit admin_users_path
      # Таймаут увеличен для Selenium (headful/headless) — админка грузится
      # медленнее Cuprite (флаки «таблица не появилась»).
      wait_for_selector('[data-admin-users-list]', timeout: 35)
      expect(page).to have_content('new_traveler@example.com')
    end
  end
end
