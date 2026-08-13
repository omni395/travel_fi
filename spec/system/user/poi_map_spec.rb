# frozen_string_literal: true

require 'rails_helper'

#
# POI Map — пользовательская карта (браузер А → браузер Б).
# А создаёт POI в Лондоне (fallback-центр карты) → Б на /pois видит его
# в скрытом контейнере #poi-map-features (данные для маркеров).
#
# Live-карта требует ВИДИМОГО окна Chrome (spec/support/cuprite.rb:
# headful + slowmo) — OpenLayers отрисовывает первый кадр, postrender
# срабатывает и #poi-map-features наполняется. Без headful-окна карта
# не инициализируется детерминированно (ROADMAP 4.8).
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

      # Гарантируем готовность окна сессии ДО CDP-вызова: execute_cdp требует
      # активного таргета окна. При неинициализированной сессии window-цепочка
      # разваливается (симптомы: 'handle' must be a string / slice for nil).
      prepare_session_window

      # Детерминированная геолокация: переопределяем координаты на Лондон через CDP
      # ДО visit pois_path. Карта центрируется на Лондон, bounds покрывают POI,
      # #poi-map-features наполняется. Без override headful Chrome возвращает
      # реальные координаты машины → bounds не Лондон → маркеры пусты.
      # Selenium Chrome CDP: переопределяем геолокацию на Лондон ДО visit pois_path.
      # Карта центрируется на Лондон, bounds покрывают POI, #poi-map-features
      # наполняется. Без override headful Chrome возвращает реальные координаты
      # машины → bounds не Лондон → маркеры пусты (флаки-падения).
      retry_cdp_geolocation(latitude: 51.5074, longitude: -0.1278, accuracy: 100)

      visit pois_path
      wait_for_selector('#poi-map-features [data-poi-id]', timeout: 90)
      # visible: false — контейнер #poi-map-features скрыт (class="hidden"),
      # Capybara по умолчанию игнорирует скрытые элементы.
      expect(page).to have_css('#poi-map-features [data-poi-name="London Fountain"]', wait: 10, visible: false)
    end
  end

  it 'маркер пользователя (.poi-user-pin) отображается на карте после геолокации (баг 2)' do
    browser_a do
      sign_in_via_ui(user_a)
      # Точка рядом с геолокацией, чтобы карта отрисовалась надёжно
      PoiService.create(
        params: {
          poi_category_id: category.id,
          name: { 'en' => 'London Clock', 'ru' => 'Лондонские часы', 'es' => 'Reloj de Londres', 'zh' => '伦敦时钟' },
          latitude: 51.5074,
          longitude: -0.1278,
          status: 'approved'
        },
        current_user: user_a
      )
    end

    browser_b do
      sign_in_via_ui(user_b)
      prepare_session_window
      retry_cdp_geolocation(latitude: 51.5074, longitude: -0.1278, accuracy: 100)

      visit pois_path
      # Ждём инициализации карты (данные маркеров) и булавки пользователя
      wait_for_selector('#poi-map-features [data-poi-id]', timeout: 90)
      wait_for_selector('.poi-user-pin', timeout: 90)

      # Булавка пользователя — mdi-navigation, зелено-голубая гамма
      expect(page).to have_css('.poi-user-pin .mdi-navigation', wait: 10)
      expect(page).to have_css('.poi-user-pin__ping', wait: 10)
    end
  end

  it 'точки на карте синхронизированы с точками в сайдбаре (баг 2)' do
    browser_a do
      sign_in_via_ui(user_a)
      # Небольшой набор в одной области — все влезают в первую страницу сайдбара
      [
        [51.5074, -0.1278, 'London Fountain A'],
        [51.5079, -0.0877, 'London Bridge B'],
        [51.5085, -0.0970, 'London Eye C']
      ].each do |lat, lng, name|
        PoiService.create(
          params: {
            poi_category_id: category.id,
            name: { 'en' => name, 'ru' => name, 'es' => name, 'zh' => name },
            latitude: lat,
            longitude: lng,
            status: 'approved'
          },
          current_user: user_a
        )
      end
    end

    browser_b do
      sign_in_via_ui(user_b)
      prepare_session_window
      retry_cdp_geolocation(latitude: 51.5079, longitude: -0.0877, accuracy: 100)

      visit pois_path
      wait_for_selector('#poi-map-features [data-poi-id]', timeout: 90)
      # Список сайдбара наполняется тем же рефлексом load_pois_in_bounds
      wait_for_selector('#poi-list [data-poi-id]', timeout: 90)

      # Множества data-poi-id на карте и в сайдбаре совпадают (обе — из одного
      # PoiReflex#load_pois_in_bounds: bounds для маркеров и первая страница для списка).
      map_ids = page.all('#poi-map-features [data-poi-id]', visible: false).map { |el| el['data-poi-id'] }.sort
      list_ids = page.all('#poi-list [data-poi-id]').map { |el| el['data-poi-id'] }.sort
      expect(list_ids).not_to be_empty
      expect(map_ids).to contain_exactly(*list_ids)
    end
  end
end
