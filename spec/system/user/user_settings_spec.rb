# frozen_string_literal: true

require 'rails_helper'

#
# User Settings — изменение настроек уведомлений (браузер А → состояние в БД).
# А обновляет настройку через SettingService (как делает SettingsReflex) →
# значение сохраняется в БД (Setting с аудитом через PaperTrail).
#
RSpec.describe 'User Settings (браузер А → состояние)', type: :system do
  let!(:user) { create(:user, :with_setting) }

  it 'А включает email-уведомления для события активного юзера → сохраняется' do
    browser_a do
      sign_in_via_ui(user)
      visit user_settings_path(id: user)
      wait_for_selector('#notifications')

      SettingService.update(user.setting, 'active_user_email_enabled', true)
    end

    # Значение зафиксировано в БД (единый источник правды)
    expect(user.setting.reload.active_user_email_enabled).to be(true)

    # PaperTrail зафиксировал изменение (аудит)
    expect(PaperTrail::Version.where(item_type: 'Setting', item_id: user.setting.id)).to exist
  end
end
