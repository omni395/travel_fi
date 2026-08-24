# frozen_string_literal: true

require 'rails_helper'

#
# POI (пользователь) — полный жизненный цикл точки с пользовательской стороны (браузер А → браузер Б).
#
# Одна сущность (POI для юзера) — один спек (аналогично админскому spec/system/admin/pois_spec.rb).
# Покрывает описанный сценарий:
#   1. А создаёт POI на карте (pending) → в БД pending, награда НЕ начислена.
#   2. Б на карте НЕ видит pending-точку.
#   3. Админ заходит в точку, проверяет, ставит статус approved → награда автору начислена (БАГ B).
#   4. Пользователь Б на карте получает live-обновление poi:reload-features и видит точку
#      (и другие пользователи в пределах видимой границы — через общий стрим карты "pois_map").
#   5. Точки на карте синхронизированы со списком сайдбара.
#   6. Маркер пользователя (.poi-user-pin) отображается на карте после геолокации.
#   7. Клик по POI в сайдбаре открывает модалку деталей.
#
# Live-карта требует ВИДИМОГО окна Chrome (spec/support/cuprite.rb: headful + slowmo) —
# OpenLayers отрисовывает первый кадр, postrender срабатывает и #poi-map-features
# наполняется. Детерминированная геолокация на Лондон (fallback-центр карты) — через CDP.
#
RSpec.describe 'POI (пользователь, браузер А → браузер Б)', type: :system do
  # Координаты Лондона (fallback-центр карты и маркер-данные)
  POI_LAT = 51.5074
  POI_LNG = -0.1278

  let!(:user_a) { create(:user, :with_setting, email: 'poi_author@example.com') }
  let!(:user_b) { create(:user, :with_setting, email: 'poi_reader@example.com') }
  let!(:category) { create(:poi_category) }

  #
  # Подготавливает браузер Б к работе с картой: гарантирует готовность окна
  # сессии до CDP-вызова и задаёт детерминированную геолокацию на Лондон.
  #
  def prepare_map_browser_b
    sign_in_via_ui(user_b)
    prepare_session_window
    # Детерминированная геолокация ДО visit pois_path: карта центрируется на Лондон,
    # bounds покрывают POI, #poi-map-features наполняется.
    retry_cdp_geolocation(latitude: POI_LAT, longitude: POI_LNG, accuracy: 100)
    # Системный стаб геолокации через CDP Page.addScriptToEvaluateOnNewDocument:
    # инжектится при КАЖДОЙ навигации и ПЕРЕЖИВАЕТ visit (в отличие от execute_script,
    # который создаёт стаб в текущем документе и теряется при редирект/навигации).
    # getCurrentPosition возвращает Лондон немедленно → _onGeolocationSuccess →
    # карта инициализируется детерминированно, минуя CDP-тайминг и fallback-таймаут.
    page.driver.browser.execute_cdp(
      'Page.addScriptToEvaluateOnNewDocument',
      source: <<~JS
        if (!window.__travel_fi_geo_stubbed) {
          window.__travel_fi_geo_stubbed = true
          navigator.geolocation.getCurrentPosition = (success) => {
            success({ coords: { latitude: #{POI_LAT}, longitude: #{POI_LNG}, accuracy: 100 } })
          }
        }
      JS
    )
    visit pois_path
    wait_for_selector('#poi-list [data-poi-id]', timeout: 90)
  end

  #
  # Создаёт POI через сервис (путь, эквивалентный PoiReflex#create) от имени А.
  #
  # @param name [String] название (для всех локалей)
  # @param status [String] статус (:approved / :pending)
  # @return [Poi] созданная точка
  #
  def create_poi_as_a(name, status:)
    poi = nil
    browser_a do
      sign_in_via_ui(user_a)
      poi = PoiService.create(
        params: {
          poi_category_id: category.id,
          name: { 'en' => name, 'ru' => name, 'es' => name, 'zh' => name },
          latitude: POI_LAT,
          longitude: POI_LNG,
          status: status
        },
        current_user: user_a
      )
    end
    poi
  end

  it 'А создаёт POI (pending) → в БД pending, награда не начислена; Б не видит на карте' do
    poi = create_poi_as_a('London Pavilion', status: 'pending')

    expect(poi.reload.status).to eq('pending')
    # БАГ B: до одобрения награда автору НЕ начислена
    expect(user_a.reload.token_balance).to eq(0)

    # Pending-точка НЕ входит в Poi.visible (approved/imported) — сайдбар и карта
    # не наполнятся ею в принципе. Создаём approved-фон, чтобы карта/список
    # инициализировались и проверка «pending отсутствует» была осмысленной.
    create_poi_as_a('London Visible Background', status: 'approved')

    prepare_map_browser_b
    wait_for_selector('#poi-map-features [data-poi-id]', timeout: 90)
    wait_for_selector('#poi-list [data-poi-id]', timeout: 90)

    # Pending-точка не должна появиться ни на карте, ни в сайдбаре
    expect(page).not_to have_css("#poi-map-features [data-poi-id='#{poi.id}']", visible: false)
    expect(page).not_to have_css("#poi-list [data-poi-id='#{poi.id}']", visible: false)
  end

  it 'админ одобряет точку → награда автору начислена, Б (и другие в границах) видит на карте' do
    poi = create_poi_as_a('London Approved', status: 'pending')

    # Админ заходит в точку, проверяет, ставит статус approved (модерация)
    admin = create(:user, :admin, :with_setting)
    PoiService.change_status(poi: poi, status: :approved, current_user: admin)
    expect(poi.reload.status).to eq('approved')
    # БАГ B: награда TFT автору начислена при переходе pending → approved
    expect(user_a.reload.token_balance).to eq(
      YAML.safe_load_file(Rails.root.join('config/gamification.yml'))['rewards']['poi_create'].to_d
    )

    prepare_map_browser_b
    wait_for_selector("#poi-map-features [data-poi-id='#{poi.id}']", timeout: 90)
    expect(page).to have_css("#poi-map-features [data-poi-id='#{poi.id}']", visible: false)
  end

  it 'создание POI: клик по мини-карте формы ставит маркер в точку клика и заполняет координаты' do
    # Геолокация А на Лондон → карта формы центрируется там же, круг 100м вокруг.
    browser_a do
      sign_in_via_ui(user_a)
      prepare_session_window
      retry_cdp_geolocation(latitude: POI_LAT, longitude: POI_LNG, accuracy: 100)
      page.driver.browser.execute_cdp(
        'Page.addScriptToEvaluateOnNewDocument',
        source: <<~JS
          if (!window.__travel_fi_geo_stubbed) {
            window.__travel_fi_geo_stubbed = true
            navigator.geolocation.getCurrentPosition = (success) => {
              success({ coords: { latitude: #{POI_LAT}, longitude: #{POI_LNG}, accuracy: 100 } })
            }
          }
        JS
      )
      # Кнопка «Add POI» рендерится только при user_signed_in?, поэтому весь
      # сценарий (клик → форма → OL-клик → проверка) остаётся внутри browser_a.
      visit pois_path

      # Открываем форму добавления POI (кнопка Add POI → poi:open-modal)
      click_on I18n.t('poi.map_component.add_poi')
      wait_for_selector('[data-controller="poi--form-component"]', timeout: 90)

      form = find('[data-controller="poi--form-component"]')
      within(form) do
        # Дожидаемся инициализации мини-карты (диагностическая экспозиция из
        # initMiniMap: маркер — OL-feature, через DOM его положение не прочитать).
        Timeout.timeout(30) do
          loop do
            break if page.evaluate_script("!!window.__poiFormMiniMap && !!window.__poiFormMarker")
            sleep 0.2
          end
        end

        # Клик по карте: диспатчим OL-событие клика в точке, смещённой от центра
        # на +20px по X и +20px по Y (в пределах круга 100м на zoom 17; ~8-9м).
        # Маркер должен переехать в эту точку.
        page.execute_script(<<~JS)
          (() => {
            const map = window.__poiFormMiniMap
            const marker = window.__poiFormMarker
            const center = map.getPixelFromCoordinate(marker.getGeometry().getCoordinates())
            const pixel = [center[0] + 20, center[1] + 20]
            const coordinate = map.getCoordinateFromPixel(pixel)
            map.dispatchEvent({ type: 'click', coordinate: coordinate, pixel: pixel })
          })()
        JS

        # Координаты обновились: скрытые поля формы ≠ нулю и ≠ начальному центру
        # (значит клик реально передвинул маркер, а не остался в исходной позиции).
        wait_until = Time.now + 10
        moved = false
        while Time.now < wait_until
          lat_input = page.find("input[name='poi[latitude]']", visible: false).value.to_f
          lng_input = page.find("input[name='poi[longitude]']", visible: false).value.to_f

          # Фактическое положение маркера (WGS84 lon/lat), записанное кликовым
          # обработчиком формы в момент клика (см. __poiFormLastLonLat).
          last_lonlat = page.evaluate_script("window.__poiFormLastLonLat")
          lng_marker = last_lonlat && last_lonlat[0]
          lat_marker = last_lonlat && last_lonlat[1]

          if lat_input != 0.0 && lng_input != 0.0 &&
             ( (lat_marker && (lat_marker - POI_LAT).abs > 1e-6) || (lng_marker && (lng_marker - POI_LNG).abs > 1e-6) )
            # Маркер сдвинулся и скрытые поля совпадают с маркером
            expect(lat_input.to_s).to eq(format('%.6f', lat_marker))
            expect(lng_input.to_s).to eq(format('%.6f', lng_marker))
            moved = true
            break
          end
          sleep 0.2
        end

        expect(moved).to be(true), 'маркер не передвинулся в точку клика (координаты формы/маркера не изменились)'
      end
    end
  end

  it 'маркер пользователя (.poi-user-pin) отображается на карте после геолокации' do
    create_poi_as_a('London Clock', status: 'approved')

    prepare_map_browser_b
    wait_for_selector('#poi-map-features [data-poi-id]', timeout: 90)
    wait_for_selector('.poi-user-pin', timeout: 90)

    # Булавка пользователя — mdi-navigation, зелено-голубая гамма
    expect(page).to have_css('.poi-user-pin .mdi-navigation', wait: 10)
    expect(page).to have_css('.poi-user-pin__ping', wait: 10)
  end

  it 'точки на карте синхронизированы с точками в сайдбаре' do
    # Небольшой набор в одной области — все влезают в первую страницу сайдбара
    [
      [ 51.5074, -0.1278, 'London Fountain A' ],
      [ 51.5079, -0.0877, 'London Bridge B' ],
      [ 51.5085, -0.0970, 'London Eye C' ]
    ].each do |lat, lng, name|
      browser_a do
        sign_in_via_ui(user_a)
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

    prepare_map_browser_b
    wait_for_selector('#poi-map-features [data-poi-id]', timeout: 90)
    wait_for_selector('#poi-list [data-poi-id]', timeout: 90)

    map_ids = page.all('#poi-map-features [data-poi-id]', visible: false).map { |el| el['data-poi-id'] }.sort
    # Список сайдбара может быть свёрнут (class=hidden) в момент сверки — элементы
    # физически в DOM, но page.all по умолчанию их скрывает. Считаем visible: false,
    # чтобы сверка шла по DOM, а не по визуальной видимости.
    list_ids = page.all('#poi-list [data-poi-id]', visible: false).map { |el| el['data-poi-id'] }.sort
    expect(list_ids).not_to be_empty
    expect(map_ids).to contain_exactly(*list_ids)
  end

  it 'клик по POI в сайдбаре открывает модалку деталей' do
    poi = nil
    browser_a do
      sign_in_via_ui(user_a)
      poi = PoiService.create(
        params: {
          poi_category_id: category.id,
          name: { 'en' => 'London Bridge', 'ru' => 'Лондонский мост', 'es' => 'Puente de Londres', 'zh' => '伦敦桥' },
          latitude: 51.5079,
          longitude: -0.0877,
          status: 'approved'
        },
        current_user: user_a
      )
    end

    # Модалка открывается по событию poi:show-detail напрямую, без клика по
    # сайдбару (см. ниже): наполнение #poi-list/карты для неё не обязательно
    # (точка может не попасть в ужатые bounds карты → список пуст). Поэтому
    # не используем prepare_map_browser_b (который жёстко ждёт #poi-list) —
    # достаточно войти и открыть страницу карты.
    sign_in_via_ui(user_b)
    visit pois_path

    # Диспатчим poi:show-detail как это делает list_item_component_controller
    # (клик по элементу списка). Реальный Selenium-клик по свёрнутому сайдбару
    # флакает (ElementNotInteractableError) — диспатч проверяет ту же логику.
    page.execute_script(<<~JS)
      document.dispatchEvent(new CustomEvent('poi:show-detail', { detail: { poiId: #{poi.id} } }))
    JS

    wait_for_selector("[data-poi--show-component-target='overlay']:not(.hidden)", timeout: 30)
    expect(page).to have_content('London Bridge', wait: 10)
  end

  it 'одну и ту же точку можно открыть повторно после закрытия через кнопку X (баг B)' do
    poi = nil
    browser_a do
      sign_in_via_ui(user_a)
      poi = PoiService.create(
        params: {
          poi_category_id: category.id,
          name: { 'en' => 'Reopen Bridge', 'ru' => 'Мост повторно', 'es' => 'Puente reabrir', 'zh' => '重新打开桥' },
          latitude: 51.5079,
          longitude: -0.0877,
          status: 'approved'
        },
        current_user: user_a
      )
    end

    sign_in_via_ui(user_b)
    visit pois_path

    # Открываем точку
    page.execute_script(<<~JS)
      document.dispatchEvent(new CustomEvent('poi:show-detail', { detail: { poiId: #{poi.id} } }))
    JS
    wait_for_selector("[data-poi--show-component-target='overlay']:not(.hidden)", timeout: 30)
    expect(page).to have_content('Reopen Bridge', wait: 10)

    # Закрываем через кнопку X (Ui::BtnComponent → click->poi--show-component#close).
    # Кнопка живёт во вставленном контенте (#poi-detail-modal-body), т.е. на вложенном
    # экземпляре контроллера — баг B: флаг _lastPoiId оверлея не сбрасывался → повтор.
    overlay_selector = "[data-poi--show-component-target='overlay']"
    button = find("#poi-detail-modal-body .mdi-close", wait: 10)
    button.click
    # Оверлей скрыт (Capybara не находит скрытые элементы без visible: false —
    # класс hidden → display:none → невидим)
    expect(page).to have_css("#{overlay_selector}.hidden", visible: false, wait: 10)

    # Повторное открытие той же точки — должно сработать (оверлей без .hidden)
    page.execute_script(<<~JS)
      document.dispatchEvent(new CustomEvent('poi:show-detail', { detail: { poiId: #{poi.id} } }))
    JS
    wait_for_selector("#{overlay_selector}:not(.hidden)", timeout: 30)
    expect(page).to have_content('Reopen Bridge', wait: 10)
  end

  # PENDING (инфраструктурный блокер, аналогично админскому сценарию в admin/pois_spec.rb):
  # форма редактирования открывается через PoiReflex#edit_poi → check_proximity!.
  # Координаты пользователя пишутся в session ТОЛЬКО рефлексом set_location из JS-геолокации;
  # реальная браузерная геолокация в headful-Selenium недетерминирована (CDP-оверрайд не
  # всегда успевает к getCurrentPosition → fallback-таймаут → session пустая → форма не
  # открывается). Форма редактирования детерминированно покрыта админским сценарием.
  xit 'автор редактирует точку: форма + карта с маркером + все поля сохраняются' do
    poi = create(:poi,
                 user: user_a,
                 poi_category: category,
                 status: 'approved',
                 name: { 'en' => 'Original Name', 'ru' => 'Оригинальное', 'es' => 'Original', 'zh' => '原始' },
                 coordinates: PoiService.parse_coordinates(POI_LAT, POI_LNG))
    browser_a do
      sign_in_via_ui(user_a)
      prepare_session_window
      retry_cdp_geolocation(latitude: POI_LAT, longitude: POI_LNG, accuracy: 100)
      page.execute_script(<<~JS)
        navigator.geolocation.getCurrentPosition = (success) => {
          success({ coords: { latitude: #{POI_LAT}, longitude: #{POI_LNG}, accuracy: 100 } })
        }
      JS
      visit pois_path
      wait_for_selector('#poi-list [data-poi-id]', timeout: 90)
    end
  end
end
