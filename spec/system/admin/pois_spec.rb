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

  it 'админ-форма редактирования: Dropdown для категории/статуса, rating readonly (баг 6)' do
    browser_a do
      sign_in_via_ui(admin_a)
      poi = create(:poi, poi_category: category, rating: 4.5,
                   name: { 'en' => 'Berlin Edit Target', 'ru' => 'Цель редактирования', 'es' => 'Objetivo de edición', 'zh' => '编辑目标' },
                   coordinates: PoiService.parse_coordinates(52.52, 13.405), status: 'approved')

      visit admin_poi_path(id: poi.id, edit: 'true')
      wait_for_selector('[data-controller="admin--pois--poi--edit-component"]', timeout: 90)

      # Категория и статус — Ui::DropdownComponent (кнопка), НЕ <select>
      expect(page).to have_css('[data-controller="ui--dropdown-component"]', minimum: 2)
      expect(page).not_to have_css('select')

      # rating — readonly-значение, НЕ редактируемое поле
      expect(page).to have_content('4.5')
      expect(page).not_to have_field('poi[rating]')
    end
  end

  it 'обратный геокодинг: адрес по координатам автозаполняет поля формы (баг 1)' do
    # ReverseGeocodingService — внешний HTTP (Nominatim), в тесте замокан.
    allow(ReverseGeocodingService).to receive(:reverse_geocode)
      .and_return(country: 'Ukraine', city: 'Kyiv', address: 'Taras Shevchenko Blvd, 12', zip_code: '01001')

    browser_a do
      sign_in_via_ui(admin_a)
      poi = create(:poi, poi_category: category, status: 'approved',
                   coordinates: PoiService.parse_coordinates(50.4501, 30.5234))

      visit admin_poi_path(id: poi.id, edit: 'true')
      wait_for_selector('[data-controller="admin--pois--poi--edit-component"]', timeout: 90)

      # Мини-карта формы инициализируется в single-interactive режиме → запускается
      # обратный геокодинг по координатам (PoiReflex#reverse_geocode → CableReady set_attribute)
      wait_for_selector("[name='poi[address]'][value='Taras Shevchenko Blvd, 12']", timeout: 90)
      expect(page).to have_field('poi[city]', with: 'Kyiv')
      expect(page).to have_field('poi[country]', with: 'Ukraine')
      expect(page).to have_field('poi[zip_code]', with: '01001')
    end
  end

  it 'сохранение формы редиректит на просмотр точки, Б видит её на карте (баг 1)' do
    browser_a do
      sign_in_via_ui(admin_a)
      poi = create(:poi, poi_category: category, status: 'approved',
                   coordinates: PoiService.parse_coordinates(51.5074, -0.1278))

      visit admin_poi_path(id: poi.id, edit: 'true')
      wait_for_selector('[data-controller="admin--pois--poi--edit-component"]', timeout: 90)

      # Заполняем имя и сохраняем через форму (Admin::PoisReflex#update)
      edit_component = find('[data-controller="admin--pois--poi--edit-component"]')
      within(edit_component) do
        find("input[name='poi[slug]']").fill_in(with: '')
        find("input[name='poi[name][en]']").fill_in(with: 'London Fountain Edited')
        find("button[type='submit']").click
      end

      # Редирект на детальную страницу точки (после сохранения edit) — обёртка #poi-detail
      wait_for_selector('#poi-detail', timeout: 90)
      expect(page).to have_current_path(admin_poi_path(id: poi), wait: 30)
    end

    # Б (пользовательская карта) видит обновлённую точку наравне с approved
    browser_b do
      sign_in_via_ui(admin_b)
      prepare_session_window
      retry_cdp_geolocation(latitude: 51.5074, longitude: -0.1278, accuracy: 100)
      visit pois_path
      wait_for_selector('#poi-map-features [data-poi-name="London Fountain Edited"]', timeout: 90)
      expect(page).to have_css('#poi-map-features [data-poi-name="London Fountain Edited"]', visible: false)
    end
  end
end
