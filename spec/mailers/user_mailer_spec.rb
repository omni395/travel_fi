# frozen_string_literal: true

require 'rails_helper'

#
# UserMailer — unit-тесты писем (Devise + Noticed).
#
# Регрессия FIX 1/FIX 6:
# - password_change (Devise send_password_change_notification) — метод и шаблоны существуют;
# - greeting-ключи рендерятся с именем пользователя (без литерала «%{recipient}»)
#   и без «translation missing» (полные devise.mailer.* локали в 4 языках).
#
RSpec.describe UserMailer, type: :mailer do
  let(:user) { create(:user, name: 'Alice Traveler') }

  #
  # Возвращает тексты всех частей письма (html/text), чтобы проверять
  # multipart-письма (mail.body.to_s для multipart возвращает пустую строку).
  #
  # @param mail [Mail::Message] письмо
  # @return [Array<String>] тексты частей
  #
  def mail_bodies(mail)
    bodies = []
    bodies << mail.text_part.body.to_s if mail.text_part
    bodies << mail.html_part.body.to_s if mail.html_part
    bodies << mail.body.to_s unless mail.multipart?
    bodies
  end

  #
  # Проверяет «чистоту» письма: наличие имени в greeting в любой части,
  # отсутствие нераскрытых интерполяций и отсутствие missing translation.
  #
  # @param mail [Mail::Message] письмо для проверки
  #
  def expect_clean_mail(mail)
    bodies = mail_bodies(mail)
    expect(bodies).not_to be_empty
    expect(bodies.any? { |body| body.include?(user.name) }).to be(true)
    bodies.each do |body|
      expect(body).not_to include('%{recipient}')
      expect(body).not_to include('%{name}')
      expect(body).not_to include('translation missing')
    end
  end

  describe '#confirmation_instructions' do
    it 'валидное письмо с именем в greeting' do
      mail = described_class.confirmation_instructions(user, 'token123')
      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq(I18n.t('devise.mailer.confirmation_instructions.subject'))
      expect_clean_mail(mail)
    end
  end

  describe '#reset_password_instructions' do
    it 'валидное письмо с именем в greeting' do
      mail = described_class.reset_password_instructions(user, 'token123')
      expect(mail.to).to eq([user.email])
      expect_clean_mail(mail)
    end
  end

  describe '#email_changed' do
    it 'валидное письмо с именем в greeting' do
      mail = described_class.email_changed(user)
      expect(mail.to).to eq([user.email])
      expect_clean_mail(mail)
    end
  end

  describe '#unlock_instructions' do
    it 'валидное письмо с именем в greeting' do
      mail = described_class.unlock_instructions(user, 'token123')
      expect(mail.to).to eq([user.email])
      expect_clean_mail(mail)
    end
  end

  describe '#password_change' do
    it 'отправляет письмо об изменении пароля (Devise password_change)' do
      mail = described_class.password_change(user)
      expect(mail.to).to eq([user.email])
      expect(mail.subject).to eq(I18n.t('devise.mailer.password_change.subject'))
      expect_clean_mail(mail)
    end
  end

  describe '#account_deleted' do
    it 'валидное письмо с именем' do
      mail = described_class.account_deleted(user)
      expect(mail.to).to eq([user.email])
      expect_clean_mail(mail)
    end
  end

  describe '#profile_updated (Noticed)' do
    it 'валидное письмо с именем' do
      mail = described_class.with(recipient: user).profile_updated
      expect(mail.to).to eq([user.email])
      expect_clean_mail(mail)
    end
  end

  describe '#osm_import_complete (Noticed)' do
    it 'валидное письмо с именем' do
      mail = described_class.with(recipient: user).osm_import_complete
      expect(mail.to).to eq([user.email])
      expect_clean_mail(mail)
    end
  end
end
