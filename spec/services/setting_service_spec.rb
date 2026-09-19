# frozen_string_literal: true

require 'rails_helper'

#
# SettingService — unit-тесты сервиса управления настройками.
#
RSpec.describe SettingService, type: :service do
  let(:user) { create(:user, :with_setting) }
  let(:setting) { user.setting }

  describe 'PERMITTED_FIELDS' do
    it 'содержит мастер-флаги' do
      expect(SettingService::PERMITTED_FIELDS).to include('notifications_enabled', 'email_enabled', 'push_enabled')
    end

    it 'содержит события юзера и админа' do
      expect(SettingService::PERMITTED_FIELDS).to include('my_poi_status_email_enabled', 'system_alert_push_enabled')
    end
  end

  describe '#update' do
    it 'обновляет разрешённое поле' do
      result = SettingService.update(setting, 'my_poi_status_email_enabled', true)
      expect(result).to be true
      expect(setting.reload.my_poi_status_email_enabled).to be true
    end

    it 'нормализует строковое значение в boolean' do
      SettingService.update(setting, 'my_poi_status_email_enabled', 'true')
      expect(setting.reload.my_poi_status_email_enabled).to be true
    end

    it 'игнорирует запрещённое поле (mass-assignment защита)' do
      expect(SettingService.update(setting, 'user_id', 999)).to be false
      expect(SettingService.update(setting, 'gamification_config', {})).to be false
    end
  end

  describe '#toggle' do
    it 'инвертирует булевое поле из актуального состояния' do
      setting.update!(my_poi_status_email_enabled: false)
      new_value = SettingService.toggle(setting, 'my_poi_status_email_enabled')
      expect(new_value).to be true
      expect(setting.reload.my_poi_status_email_enabled).to be true
    end

    it 'возвращает false для запрещённого поля' do
      expect(SettingService.toggle(setting, 'user_id')).to be false
    end
  end

  describe '#update_gamification' do
    it 'обновляет числовое значение rewards на глобальной записи' do
      expect(SettingService.update_gamification('rewards', 'poi_create', '12')).to be true
      global = Setting.global_settings
      expect(global.reload.gamification_config.dig('rewards', 'poi_create')).to eq(12)
    end

    it 'обновляет числовое значение pool' do
      expect(SettingService.update_gamification('pool', 'lock_days', '3')).to be true
      expect(Setting.global_settings.reload.gamification_config.dig('pool', 'lock_days')).to eq(3)
    end

    it 'отклоняет нечисловое значение и недопустимую секцию' do
      expect(SettingService.update_gamification('badges', '1', '10')).to be false
      expect(SettingService.update_gamification('rewards', 'poi_create', 'abc')).to be false
    end
  end
end
