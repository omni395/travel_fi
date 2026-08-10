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

      # Детерминированная геолокация: переопределяем координаты на Лондон через CDP
      # ДО visit pois_path. Карта центрируется на Лондон, bounds покрывают POI,
      # #poi-map-features наполняется. Без override headful Chrome возвращает
      # реальные координаты машины → bounds не Лондон → маркеры пусты.
      # Selenium Chrome CDP: переопределяем геолокацию на Лондон ДО visit pois_path.
      # Карта центрируется на Лондон, bounds покрывают POI, #poi-map-features
      # наполняется. Без override headful Chrome возвращает реальные координаты
      # машины → bounds не Лондон → маркеры пусты (флаки-падения).
      page.driver.browser.execute_cdp(
        'Emulation.setGeolocationOverride',
        latitude: 51.5074,
        longitude: -0.1278,
        accuracy: 100
      )

      visit pois_path
      wait_for_selector('#poi-map-features [data-poi-id]', timeout: 90)
      # visible: false — контейнер #poi-map-features скрыт (class="hidden"),
      # Capybara по умолчанию игнорирует скрытые элементы.
      expect(page).to have_css('#poi-map-features [data-poi-name="London Fountain"]', wait: 10, visible: false)
    end
  end
end
