# frozen_string_literal: true

require 'rails_helper'

#
# Admin Users — модерация пользователей (браузер А → браузер Б).
# А меняет статус юзера (через сервис, как это делает Reflex) → Б видит в таблице.
#
RSpec.describe 'Admin Users (браузер А → браузер Б)', type: :system do
  let!(:admin_a) { create(:user, :admin, :with_setting) }
  let!(:admin_b) { create(:user, :admin, :with_setting) }
  let!(:target_user) { create(:user) }

  it 'А меняет статус юзера → Б видит обновлённый статус в таблице' do
    browser_a do
      sign_in_via_ui(admin_a)
      Admin::UserService.change_status(user: target_user, status: 'suspended', current_user: admin_a)
    end

    browser_b do
      sign_in_via_ui(admin_b)
      visit admin_users_path
      # Таймаут увеличен для Selenium headful (последовательные system-тесты
      # грузят админку медленнее Cuprite — флаки «таблица не появилась»).
      wait_for_selector('[data-admin-users-list]', timeout: 30)
      expect(page).to have_content(target_user.email)
      expect(page).to have_content(I18n.t('activerecord.attributes.user.statuses.suspended'))
    end
  end
end
