# frozen_string_literal: true

require 'rails_helper'

#
# L — email-доставка Noticed (ROADMAP 4.5).
# Проверка: mailer формирует письмо получателю через params[:recipient],
# Setting-фильтр, на который опирается UserProfileNotification#email_enabled?
# (метод setting_field_enabled? строит "#{event_type}_email_enabled?").
#
RSpec.describe 'Noticed email-доставка (ROADMAP 4.5)' do
  let(:user) { create(:user, :with_setting) }

  describe 'UserMailer.profile_updated' do
    it 'отправляет письмо получателю (params[:recipient])' do
      email = UserMailer.with(recipient: user).profile_updated

      expect(email.to).to include(user.email)
      expect(email.subject).to be_present
    end
  end

  describe 'Setting-фильтр email (база UserProfileNotification#email_enabled?)' do
    it 'Setting отвечает на user_updated_by_user_email_enabled? = true' do
      user.setting.update!(user_updated_by_user_email_enabled: true)

      expect(user.setting).to respond_to(:user_updated_by_user_email_enabled?)
      expect(user.setting.user_updated_by_user_email_enabled?).to be true
    end

    it 'false при выключенной настройке' do
      user.setting.update!(user_updated_by_user_email_enabled: false)

      expect(user.setting.user_updated_by_user_email_enabled?).to be false
    end
  end
end
