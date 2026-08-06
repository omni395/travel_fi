# frozen_string_literal: true

require 'rails_helper'

#
# Setting — unit-тесты модели настроек уведомлений.
#
RSpec.describe Setting, type: :model do
  describe 'валидации' do
    it 'требует уникальный user_id' do
      setting = create(:setting)
      expect(build(:setting, user: setting.user)).not_to be_valid
    end
  end

  describe '.create_for_user' do
    it 'создаёт настройки идемпотентно' do
      user = create(:user)

      first = Setting.create_for_user(user)
      second = Setting.create_for_user(user)

      expect(second).to eq(first)
    end
  end

  describe 'алиасы user-facing полей' do
    it 'profile_updated_* мапятся на user_updated_by_user_*' do
      setting = create(:setting)

      setting.update!(profile_updated_email_enabled: true)

      expect(setting.reload.user_updated_by_user_email_enabled).to be true
    end
  end
end
