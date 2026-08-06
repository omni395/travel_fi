# frozen_string_literal: true

require 'rails_helper'

#
# SettingService — unit-тесты сервиса настроек уведомлений.
#
RSpec.describe SettingService, type: :service do
  it 'обновляет поле настройки' do
    setting = create(:setting)

    SettingService.update(setting, :new_registration_email_enabled, true)

    expect(setting.reload.new_registration_email_enabled).to be true
  end

  it 'игнорирует несуществующее поле' do
    setting = create(:setting)

    expect { SettingService.update(setting, :nonexistent_field, true) }.not_to raise_error
  end
end
