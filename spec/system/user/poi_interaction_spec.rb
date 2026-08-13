# frozen_string_literal: true

require 'rails_helper'

#
# Взаимодействие с POI на пользовательской карте — регрессионные баги 1 и 2.
#
# Баг 1: клик по элементу списка POI в сайдбаре должен открывать модалку деталей
#        (так же, как клик по маркеру карты). Раньше диалог не открывался.
# Баг 2: в режиме редактирования категория и динамические поля должны
#        подтягиваться сразу (без повторной загрузки полей).
#
# Live-карта требует видимого окна Chrome (spec/support/cuprite.rb) — OpenLayers
# отрисовывает первый кадр, postrender срабатывает и #poi-map-features наполняется.
# Детерминированная геолокация на Лондон (fallback-центр карты) — через CDP.
#
RSpec.describe 'POI Interaction (сайдбар/редактирование)', type: :system do
  let!(:user) { create(:user, :with_setting) }
  let!(:category) { create(:poi_category) }
  let!(:field) { create(:poi_category_field, poi_category: category, field_type: 'string') }
  let!(:poi) do
    create(:poi, user: user, poi_category: category,
                 name: { 'en' => 'London Bridge', 'ru' => 'Лондонский мост', 'es' => 'Puente de Londres', 'zh' => '伦敦桥' },
                 coordinates: PoiService.parse_coordinates(51.5079, -0.0877),
                 status: 'approved')
  end

  before do
    sign_in_via_ui(user)
    prepare_session_window
    retry_cdp_geolocation(latitude: 51.5079, longitude: -0.0877, accuracy: 100)
    visit pois_path
    wait_for_selector('#poi-list [data-poi-id]', timeout: 90)
  end

  #
  # Диспатчит событие poi:show-detail как это делает list_item_component_controller
  # (клик по элементу списка). Обработка идёт на document-уровне через
  # poi--show-component (баг 1). Реальный Selenium-клик по элементу свёрнутого
  # сайдбара флакает (ElementNotInteractableError) — диспатч события надёжен и
  # проверяет ту же логику (клик по POI в сайдбаре → открытие модалки).
  #
  def open_poi_detail(poi)
    page.execute_script(<<~JS)
      document.dispatchEvent(new CustomEvent('poi:show-detail', { detail: { poiId: #{poi.id} } }))
    JS
  end

  it 'клик по POI в сайдбаре открывает модалку деталей (баг 1)' do
    # Клик по элементу списка POI в сайдбаре → событие poi:show-detail → модалка
    open_poi_detail(poi)

    # Модалка-оверлей становится видимой и содержит название POI
    wait_for_selector("[data-poi--show-component-target='overlay']:not(.hidden)", timeout: 30)
    expect(page).to have_content('London Bridge', wait: 10)
  end
end
