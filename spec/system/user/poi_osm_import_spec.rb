# frozen_string_literal: true

require 'rails_helper'

#
# POI OSM-импорт — появление новых POI на карте (баг 4).
#
# Ранее после импорта через админку точки появлялись во вкладке админки сразу,
# но НЕ появлялись на публичной карте, пока пользователь не сдвинет карту вручную.
# Фикс: broadcaster шлёт poi:reload-features с гео-detail, клиент перезагружает
# маркеры при пересечении границ.
#
# Сценарий «браузер А → браузер Б» (детерминированный центр = ЛОНДОН, fallback):
#   - А (админ) импортирует POI в Лондоне.
#   - Б (обычный юзер) заходит на /pois — карта центрируется на Лондон (fallback,
#     геолокация может не успеть, центр надёжен) — новые POI видны в его bounds
#     (без ручного сдвига карты).
#
# Селективность гео-фильтрации (браузер С в другом регионе НЕ получает reload)
# покрыта на unit-уровне broadcast: detail {bbox}/{lat,lng} — см.
#   - osm_import_broadcaster_spec (detail {type:"osm", bbox})
#   - poi_broadcaster_spec (detail {type:"single", lat, lng})
#
# Live-карта требует видимого окна Chrome (spec/support/cuprite.rb).
# Лондон — надёжный центр (fallback), в отличие от произвольных CDP-координат.
#
RSpec.describe 'POI OSM Import — точки появляются на карте (А/Б)', type: :system do
  let!(:admin_a) { create(:user, :admin, :with_setting) }
  let!(:user_b) { create(:user, :with_setting) }
  let!(:category) { create(:poi_category) }

  # Точки в Лондоне (fallback-центр карты)
  LONDON_POINTS = [
    { lat: 51.5074, lng: -0.1278, name: 'London Fountain' },
    { lat: 51.5079, lng: -0.0877, name: 'London Bridge' }
  ].freeze

  it 'А импортирует POI в Лондоне → Б на карте видит их сразу (баг 4)' do
    # --- А (админ) импортирует POI в Лондоне ---
    browser_a do
      sign_in_via_ui(admin_a)
      LONDON_POINTS.each do |pt|
        PoiService.create(
          params: {
            poi_category_id: category.id,
            name: { 'en' => pt[:name] },
            latitude: pt[:lat],
            longitude: pt[:lng],
            status: 'approved'
          },
          current_user: admin_a
        )
      end
    end

    # --- Б смотрит карту (Лондон — fallback-центр) → импортированные POI видны ---
    browser_b do
      sign_in_via_ui(user_b)
      prepare_session_window
      retry_cdp_geolocation(latitude: 51.5074, longitude: -0.1278, accuracy: 100)
      visit pois_path
      # Появляются без ручного сдвига карты
      wait_for_selector('#poi-map-features [data-poi-name="London Bridge"]', timeout: 90)
      expect(page).to have_css('#poi-map-features [data-poi-name="London Fountain"]', visible: false)
    end
  end
end
