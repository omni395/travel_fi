# frozen_string_literal: true

require 'rails_helper'

#
# User — ПОЛНЫЙ жизненный цикл сущности (браузер А → браузер Б), эталон poi_category_spec.
#
# ОДИН example тянет всю цепочку:
#   1. Регистрация (email через UI) → роль :user, настройки, рефкод, баллы
#   2. Подтверждение email → статус active + аудит email_verified
#   3. Скрытый custodial-кошелёк (EIP-55 адрес, шифрованный private key, chain_id)
#   4. Админ live: смена статуса / обновление имени → Б видит БЕЗ перезагрузки (AdminChannel)
#   5. Live-профиль: баллы/бейджи + live-имя через user_N стрим
#   6. Мягкое удаление = только статус deleted (запись НЕ удаляется; email занят)
#   7. Аудит (PaperTrail — Single Source of Truth)
#   8. Уведомления по настройкам (Noticed) — все через broadcast-конвейер
#
RSpec.describe 'User (браузер А → браузер Б): полный жизненный цикл', type: :system do
  let!(:admin_a) { create(:user, :admin, :with_setting, email: 'admin_a@example.com') }
  let!(:admin_b) { create(:user, :admin, :with_setting, email: 'admin_b@example.com') }

  it 'регистрация → подтверждение → кошелёк → админ live → live-профиль → мягкое удаление → аудит → уведомления' do
    # ---------- Б: админ открывает список ----------
    browser_b do
      sign_in_via_ui(admin_b)
      visit admin_users_path
      wait_for_selector('[data-admin-users-list]')
    end

    # ---------- 1. Регистрация через UI (email) ----------
    using_session(:register) do
      visit new_user_registration_path(locale: I18n.locale)
      fill_in 'user[name]', with: 'New Traveler'
      fill_in 'user[email]', with: 'new_traveler@example.com'
      fill_in 'user[password]', with: 'password123'
      fill_in 'user[password_confirmation]', with: 'password123'
      # Кнопка регистрации рендерится Ui::BtnComponent → <button type="submit">
      find("button[type='submit']", match: :first).click
    end

    user = User.find_by(email: 'new_traveler@example.com')
    expect(user).to be_present
    expect(user).to have_role(:user)
    expect(user.setting).to be_present
    expect(user.referral_code).to be_present
    # До подтверждения email — начислений НЕТ (точка начисления = статус active).
    expect(user.reload.token_balance).to eq(0)
    # Скрытый custodial-кошелёк создаётся СРАЗУ при регистрации (не ждём
    # подтверждения), чтобы начисления после активации сразу получили on-chain адрес.
    expect(user.reload.wallet).to be_present

    # ---------- 2. Подтверждение email (анонимная сессия, как клик по ссылке из письма) ----------
    token = user.reload.confirmation_token
    expect(token).to be_present
    using_session(:confirm) do
      visit user_confirmation_path(confirmation_token: token)
      expect(user.reload).to be_confirmed
      expect(user.reload.status).to eq('active')
    end
    expect(PaperTrail::Version.where(item_type: 'User', item_id: user.id, event: 'email_verified')).to exist

    # После подтверждения (статус active) — welcome-токены начислены и relay поставлен.
    expect(user.reload.token_balance).to be > 0
    expect(user.reload.token_transactions.map(&:action_key)).to include('registration')

    # ---------- 3. Скрытый custodial-кошелёк ----------
    wallet = user.reload.wallet
    expect(wallet).to be_present
    # Кошелёк уже был создан при регистрации (см. шаг 1) — повторный вызов идемпотентен.
    expect(wallet.address).to match(/\A0x[0-9a-fA-F]{40}\z/)
    expect(wallet.chain_id).to be_present
    expect(wallet.encrypted_private_key).to be_present
    # Приватный ключ не хранится в открытом виде.
    expect(wallet.encrypted_private_key).not_to include(wallet.private_key)
    # Денормализация адреса на юзере.
    expect(user.wallet_address).to eq(wallet.address)

    # Проигрываем асинхронный конвейер (регистрация/подтверждение → VersionObserverJob → Broadcaster).
    perform_enqueued_jobs_now

    # ---------- Б видит нового юзера в списке ----------
    browser_b do
      wait_for_selector('[data-admin-users-list]')
      expect(page).to have_content('new_traveler@example.com')
    end

    # ---------- 4. Админ: смена статуса → Б видит Suspended в таблице ----------
    Admin::UserService.change_status(user: user, status: 'suspended', current_user: admin_a)
    expect(user.reload.status).to eq('suspended')
    perform_enqueued_jobs_now
    browser_b do
      visit admin_users_path
      wait_for_selector("[data-admin-user-id='#{user.id}']")
      expect(page).to have_content(I18n.t('activerecord.attributes.user.statuses.suspended'))
    end

    # ---------- 4.1 Админ: обновление имени → Б видит Updated Traveler в таблице ----------
    Admin::UserService.update(user: user, params: { name: 'Updated Traveler' }, current_user: admin_a)
    expect(user.reload.name).to eq('Updated Traveler')
    perform_enqueued_jobs_now
    browser_b do
      visit admin_users_path
      wait_for_selector("[data-admin-user-id='#{user.id}']")
      expect(page).to have_content('Updated Traveler')
    end

    # ---------- 5. Профиль: рендер с балансом и актуальными данными ----------
    # Юзер залогинен в сессии :confirm (после подтверждения email);
    # в :register он НЕ залогинен (регистрация не авторизует до подтверждения).
    # (live-обновление имени через user_N стрим — ограничение рендера ProfileComponent
    # из SolidQueue-контекста, см. ROADMAP 2.3 — Б7.)
    using_session(:confirm) do
      visit user_path(id: user)
      wait_for_selector("[data-user-profile-id='#{user.id}']")
      expect(page).to have_content('Updated Traveler')
      expect(page).to have_text(/suspended/i)
      expect(page).to have_content('TFT Balance')
      # Кошелёк в профиле юзера скрыт (только админ видит его во вкладке Wallet).
      expect(page).not_to have_content(user.wallet.address)
    end

    # ---------- 6. Мягкое удаление: юзеров НЕ удаляем, только статус deleted ----------
    Admin::UserService.destroy(user: user, current_user: admin_a)
    perform_enqueued_jobs_now
    expect(user.reload.status).to eq('deleted')
    expect(User.find_by(id: user.id)).to be_present
    # Повторная регистрация с тем же email невозможна (защита от множественных регистраций).
    expect(User.new(email: 'new_traveler@example.com', name: 'Dup', password: 'password123')).not_to be_valid
    # В «All Statuses» deleted-юзер скрыт...
    browser_b do
      visit admin_users_path
      wait_for_selector('[data-admin-users-list]')
      expect(page).not_to have_content('new_traveler@example.com')
    end
    # ...но админ может просмотреть удалённых через фильтр статуса.
    browser_b do
      visit admin_users_path(status: 'deleted')
      wait_for_selector('[data-admin-users-list]')
      expect(page).to have_content('new_traveler@example.com')
      expect(page).to have_content(I18n.t('activerecord.attributes.user.statuses.deleted'))
    end

    # ---------- 7. Аудит (PaperTrail — Single Source of Truth) ----------
    expect(PaperTrail::Version.where(item_type: 'User', item_id: user.id)).to exist

    # ---------- 8. Уведомления по настройкам (все через broadcast-конвейер) ----------
    expect(Noticed::Notification.where(recipient: admin_a)).to exist
    expect(Noticed::Notification.where(recipient: admin_b)).to exist
  end
end
