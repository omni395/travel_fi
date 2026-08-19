# frozen_string_literal: true

require 'rails_helper'

#
# Реферальные начисления TFT (браузер А → админ Б).
#
# Сценарий:
#   1. А регистрируется по рефкоду реферера (через UI)
#   2. Начисления обоим согласно плана (новому 10+5, рефереру 15)
#   3. Реферальная связь (referred_by) сохранена
#   4. Профиль А: баланс 15 TFT + история начислений
#   5. Админ Б: вкладка Wallet — баланс, реферер, транзакции с explorer-ссылкой (выжимка 4+4)
#
RSpec.describe 'Реферальные начисления TFT', type: :system do
  let!(:referrer) { create(:user, :with_setting, email: 'referrer@example.com') }
  let!(:admin_b) { create(:user, :admin, :with_setting) }

  it 'регистрация по рефкоду → начисления обоим, баланс+история в профиле, Wallet у админа' do
    # ---------- А: регистрация с рефкодом реферера ----------
    browser_a do
      visit new_user_registration_path
      fill_in 'user[name]', with: 'Referred Traveler'
      fill_in 'user[email]', with: 'referred_traveler@example.com'
      fill_in 'user[password]', with: 'password123'
      fill_in 'user[password_confirmation]', with: 'password123'
      fill_in 'user[referral_code_input]', with: referrer.referral_code
      find("button[type='submit']", match: :first).click
    end

    # Ожидаем завершения регистрации (асинхронный submit; без ожидания — гонка
    # и флаки «User.find_by → nil» при длинных наборах Selenium).
    Timeout.timeout(90) do
      sleep 0.2 until User.find_by(email: 'referred_traveler@example.com').present?
    end

    user = User.find_by(email: 'referred_traveler@example.com')
    expect(user).to be_present

    # Реферальная связь фиксируется при регистрации (переживает подтверждение).
    expect(user.reload.referred_by).to eq(referrer)
    expect(referrer.reload.referrals_count).to eq(1)
    # До подтверждения (до статуса active) — начислений НЕТ.
    expect(user.reload.token_balance).to eq(0)

    # ---------- Подтверждение email ----------
    # Регистрация НЕ авторизует до подтверждения — подтверждаем, чтобы
    # открыть профиль (после подтверждения юзер залогинен).
    confirmation_token = user.reload.confirmation_token
    browser_a do
      visit user_confirmation_path(confirmation_token: confirmation_token)
    end

    # ---------- Начисления обоим после активации ----------
    # Новому: welcome (10) + реферальный бонус новому (5) = 15.
    expect(user.reload.token_balance).to eq(15)
    # Рефереру: реферальный бонус рефереру (15).
    expect(referrer.reload.token_balance).to eq(15)
    # Журнал транзакций создан для обоих.
    expect(user.token_transactions.count).to eq(2)
    expect(referrer.token_transactions.count).to eq(1)

    # Начисление новому — БЕЗ лок-периода (БАГ A): welcome + рефбонус новому
    # мгновенно доступны, в Locked их НЕТ. Рефереру — с vesting-локом (антифрод).
    expect(user.reload.token_transactions.available.sum(:amount)).to eq(15)
    expect(user.reload.token_transactions.locked.sum(:amount)).to eq(0)
    expect(user.reload.token_transactions.map(&:action_key)).to contain_exactly(
      'registration', 'referral_bonus_new_user'
    )
    # Реферер: 15 мгновенно НЕ доступны (заблокированы на lock-период).
    expect(referrer.reload.token_transactions.available.sum(:amount)).to eq(0)
    expect(referrer.reload.token_transactions.locked.sum(:amount)).to eq(15)

    # ---------- Профиль А: баланс + история начислений ----------
    browser_a do
      visit user_path(id: user)
      wait_for_selector("[data-user-profile-id='#{user.id}']", timeout: 90)
      expect(page).to have_content('15')
      wait_for_selector('[data-user-rewards]', timeout: 90)
      expect(page).to have_content(I18n.t('users.rewards_component.title'))
      # Начисления доступны сразу (БАГ A): Available: 15, Locked: 0 — без лока.
      # Локализованные подписи плашек балансов из rewards_component.
      expect(page).to have_content("#{I18n.t('users.rewards_component.available_balance')}: 15 TFT")
      expect(page).to have_content("#{I18n.t('users.rewards_component.locked_balance')}: 0 TFT")
      # Кнопка claim доступна, т.к. есть available-начисления.
      expect(page).to have_button(I18n.t('users.rewards_component.claim_button'))
    end

    # ---------- Админ Б: вкладка Wallet ----------
    # Эмулируем on-chain подтверждение: заполняем tx_hash транзакции.
    tx = user.token_transactions.first
    tx.update_column(:tx_hash, "0x#{'a' * 64}")

    browser_b do
      sign_in_via_ui(admin_b)
      visit admin_user_path(id: user)
      wait_for_selector("[data-admin-user-wallet]", timeout: 90)
      # Переключаемся на вкладку Wallet.
      # JS-клик надёжнее нативного Selenium-клика при перерисовке страницы
      # (Stimulus-обработчик data-action гарантированно вызывается).
      page.execute_script("document.querySelector('[data-tab=wallet]').click()")
      # Ждём видимости панели Wallet (Stimulus убирает hidden).
      expect(page).to have_css("[data-tab='wallet']:not(.hidden)")
      # Баланс токенов.
      expect(page).to have_content(I18n.t('admin.users.user.wallet_component.token_balance'))
      expect(page).to have_content('15')
      # Реферальная информация (реферер).
      expect(page).to have_content(referrer.name)
      # Explorer-ссылка с выжимкой хэша 4+4.
      expect(page).to have_link(tx.short_hash, href: tx.explorer_url)
    end
  end
end
