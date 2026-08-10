# frozen_string_literal: true

require 'rails_helper'

#
# User — полный цикл сброса пароля (Devise recoverable).
#
# 1. Запрос сброса через UI → письмо reset_password_instructions
# 2. Переход по токену → ввод нового пароля
# 3. Пароль сменён → письмо password_change (регрессия FIX 1)
#
RSpec.describe 'User password reset (recoverable)', type: :system do
  let(:user) { create(:user, :with_setting) }

  it 'запрос → письмо → новый пароль → password_change письмо → вход новым паролем' do
    ActionMailer::Base.deliveries.clear

    browser_a do
      visit new_user_password_path(locale: I18n.locale)
      fill_in 'user[email]', with: user.email
      find("button[type='submit']", match: :first).click
      expect(page).to have_content(I18n.t('devise.passwords.send_instructions'))
    end

    # Письмо со ссылкой сброса отправлено
    reset_mail = ActionMailer::Base.deliveries.find do |m|
      m.subject == I18n.t('devise.mailer.reset_password_instructions.subject')
    end
    expect(reset_mail).to be_present
    expect(reset_mail.to).to include(user.email)

    # Извлекаем RAW-токен из письма: Devise хранит в БД digest (user.reset_password_token
    # возвращает digest), а в письме шлёт raw-токен — его и принимает reset_password_by_token.
    mail_body = reset_mail.text_part ? reset_mail.text_part.body.to_s : reset_mail.body.to_s
    expect(mail_body).not_to include('%{recipient}')
    token = mail_body[%r{reset_password_token=[A-Za-z0-9\-_]+}].to_s.split('=').last
    expect(token).to be_present

    browser_a do
      visit edit_user_password_path(reset_password_token: token, locale: I18n.locale)
      fill_in 'user[password]', with: 'newpassword123'
      fill_in 'user[password_confirmation]', with: 'newpassword123'
      find("button[type='submit']", match: :first).click
      expect(page).to have_content(I18n.t('devise.passwords.updated'))
    end

    # Пароль сменён
    expect(user.reload.valid_password?('newpassword123')).to be(true)

    # Письмо-уведомление об изменении пароля отправлено (FIX 1)
    password_mail = ActionMailer::Base.deliveries.find do |m|
      m.subject == I18n.t('devise.mailer.password_change.subject')
    end
    expect(password_mail).to be_present
    expect(password_mail.to).to include(user.email)
    expect(password_mail.body.to_s).not_to include('%{recipient}')
  end
end
