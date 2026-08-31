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
# Сценарий «браузер А → браузер Б» (детерминированный центр = БЕРЛИН, fallback):
#   - А (админ) импортирует POI в Берлине.
#   - Б (обычный юзер) заходит на /pois — карта центрируется на Берлин (единый
#     гео-сетап prepare_map_geolocation: CDP + стаб + форс set_location) — новые POI
#     видны в его bounds (без ручного сдвига карты).
#
# Селективность гео-фильтрации (браузер С в другом регионе НЕ получает reload)
# покрыта на unit-уровне broadcast: detail {bbox}/{lat,lng} — см.
#   - osm_import_broadcaster_spec (detail {type:"osm", bbox})
#   - poi_broadcaster_spec (detail {type:"single", lat, lng})
#
# Live-карта требует видимого окна Chrome (spec/support/cuprite.rb).
# Берлин — надёжный центр (fallback + детерминированный гео-сетап).
#
RSpec.describe 'POI OSM Import — точки появляются на карте (А/Б)', type: :system do
  let!(:admin_a) { create(:user, :admin, :with_setting) }
  let!(:user_b) { create(:user, :with_setting) }
  let!(:category) { create(:poi_category) }

  # Точки в Берлине (fallback-центр карты TestGeolocation).
  # ОБЕ точки должны попадать в видимые bounds карты при zoom 17 (область ~100-200м):
  # прошлая версия ставила London Bridge на -0.0877 (~3.5км восточнее) — точка была
  # вне bounds, не попадала в #poi-map-features, тест флакал по таймауту.
  BERLIN_POINTS = [
    { lat: 52.5200, lng: 13.4050, name: 'Berlin Fountain' },
    { lat: 52.5192, lng: 13.4058, name: 'Berlin Bridge' }
  ].freeze

  it 'А импортирует POI в Берлине → Б на карте видит их сразу (баг 4)' do
    # --- А (админ) импортирует POI в Берлине ---
    browser_a do
      sign_in_via_ui(admin_a)
      BERLIN_POINTS.each do |pt|
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

    # --- Б смотрит карту (Берлин — fallback-центр) → импортированные POI видны ---
    browser_b do
      sign_in_via_ui(user_b)
      prepare_map_geolocation
      visit pois_path
      # Ждём инициализацию карты: #poi-map-features наполняется ТОЛЬКО после
      # первого кадра OpenLayers (postrender → load_pois_in_bounds). Ожидание по
      # data-poi-id (как в poi_spec.rb) надёжнее сайта-by-name — оно ловит
      # момент, когда маркеры уже отрисованы, и убирает флак «карта не инициализировалась».
      wait_for_selector('#poi-map-features [data-poi-id]', timeout: 90)
      # Появляются без ручного сдвига карты
      wait_for_selector('#poi-map-features [data-poi-name="Berlin Bridge"]', timeout: 90)
      expect(page).to have_css('#poi-map-features [data-poi-name="Berlin Fountain"]', visible: false)
    end
  end
end
