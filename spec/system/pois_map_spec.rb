# frozen_string_literal: true

require 'rails_helper'

#
# POI Map — пользовательская карта (браузер А → браузер Б).
# А создаёт POI в Лондоне (fallback-центр карты) → Б на /pois видит его
# в скрытом контейнере #poi-map-features (данные для маркеров).
#
RSpec.describe 'POI Map (браузер А → браузер Б)', type: :system do
  let!(:user_a) { create(:user, :with_setting) }
  let!(:user_b) { create(:user, :with_setting) }
  let!(:category) { create(:poi_category) }

  it 'А создаёт POI → Б на карте получает данные маркера' do
    browser_a do
      sign_in_via_ui(user_a)
      PoiService.create(
        params: {
          poi_category_id: category.id,
          name: { 'en' => 'London Fountain', 'ru' => 'Лондонский фонтан', 'es' => 'Fuente de Londres', 'zh' => '伦敦饮水处' },
          latitude: 51.5074,
          longitude: -0.1278,
          status: 'approved'
        },
        current_user: user_a
      )
    end

    browser_b do
      sign_in_via_ui(user_b)
      visit pois_path
      wait_for_selector('#poi-map-features [data-poi-id]')
      expect(page).to have_css('#poi-map-features [data-poi-name="London Fountain"]', wait: 10)
    end
  end
end
