# frozen_string_literal: true

require 'rails_helper'

#
# Admin Pois — модерация точек (браузер А → браузер Б).
# А создаёт POI (через сервис, как это делает Reflex) → админ Б видит его в списке.
#
RSpec.describe 'Admin Pois (браузер А → браузер Б)', type: :system do
  let!(:admin_a) { create(:user, :admin, :with_setting) }
  let!(:admin_b) { create(:user, :admin, :with_setting) }
  let!(:category) { create(:poi_category) }

  it 'А создаёт POI → Б видит его в списке админки' do
    browser_a do
      sign_in_via_ui(admin_a)
      PoiService.create(
        params: {
          poi_category_id: category.id,
          name: { 'en' => 'Kyiv Central Station', 'ru' => 'Киев-Пассажирский', 'es' => 'Estación central de Kiev', 'zh' => '基辅中央车站' },
          latitude: 50.4403,
          longitude: 30.4896,
          status: 'approved'
        },
        current_user: admin_a
      )
    end

    browser_b do
      sign_in_via_ui(admin_b)
      visit admin_pois_path
      wait_for_selector('[data-admin-pois-list]')
      expect(page).to have_content('Kyiv Central Station')
    end
  end
end
