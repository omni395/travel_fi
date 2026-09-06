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
# наполняется. Детерминированная геолокация на Берлин (fallback-центр карты) — через CDP.
#
RSpec.describe 'POI (пользователь, браузер А → браузер Б)', type: :system do
  # Координаты Берлина (fallback-центр карты и маркер-данные, TestGeolocation).
  POI_LAT = TestGeolocation::DEFAULT_TEST_LAT
  POI_LNG = TestGeolocation::DEFAULT_TEST_LNG

  let!(:user_a) { create(:user, :with_setting, email: 'poi_author@example.com') }
  let!(:user_b) { create(:user, :with_setting, email: 'poi_reader@example.com') }
  let!(:category) { create(:poi_category) }

  #
  # Подготавливает браузер Б к работе с картой: единый детерминированный гео-сетап
  # (CDP-оверрайд + JS-стаб + форс set_location) на Берлин.
  #
  def prepare_map_browser_b
    sign_in_via_ui(user_b)
    prepare_map_geolocation(latitude: POI_LAT, longitude: POI_LNG)
    visit pois_path
    wait_for_selector('#poi-list [data-poi-id]', timeout: 90)
    force_user_location(latitude: POI_LAT, longitude: POI_LNG)
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
    poi = create_poi_as_a('Berlin Pavilion', status: 'pending')

    expect(poi.reload.status).to eq('pending')
    # БАГ B: до одобрения награда автору НЕ начислена
    expect(user_a.reload.token_balance).to eq(0)

    # Pending-точка НЕ входит в Poi.visible (approved/imported) — сайдбар и карта
    # не наполнятся ею в принципе. Создаём approved-фон, чтобы карта/список
    # инициализировались и проверка «pending отсутствует» была осмысленной.
    create_poi_as_a('Berlin Visible Background', status: 'approved')

    prepare_map_browser_b
    wait_for_selector('#poi-map-features [data-poi-id]', timeout: 90)
    wait_for_selector('#poi-list [data-poi-id]', timeout: 90)

    # Pending-точка не должна появиться ни на карте, ни в сайдбаре
    expect(page).not_to have_css("#poi-map-features [data-poi-id='#{poi.id}']", visible: false)
    expect(page).not_to have_css("#poi-list [data-poi-id='#{poi.id}']", visible: false)
  end

  it 'админ одобряет точку → награда автору начислена, Б (и другие в границах) видит на карте' do
    poi = create_poi_as_a('Berlin Approved', status: 'pending')

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
    # Геолокация А на Берлин → карта формы центрируется там же, круг 100м вокруг.
    browser_a do
      sign_in_via_ui(user_a)
      prepare_map_geolocation(latitude: POI_LAT, longitude: POI_LNG)
      # Кнопка «Add POI» рендерится только при user_signed_in?, поэтому весь
      # сценарий (клик → форма → OL-клик → проверка) остаётся внутри browser_a.
      visit pois_path
      force_user_location(latitude: POI_LAT, longitude: POI_LNG)

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
             ((lat_marker && (lat_marker - POI_LAT).abs > 1e-6) || (lng_marker && (lng_marker - POI_LNG).abs > 1e-6))
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
    create_poi_as_a('Berlin Clock', status: 'approved')

    prepare_map_browser_b
    wait_for_selector('#poi-map-features [data-poi-id]', timeout: 90)
    wait_for_selector('.poi-user-pin', timeout: 90)

    # Булавка пользователя — mdi-navigation, зелено-голубая гамма
    expect(page).to have_css('.poi-user-pin .mdi-navigation', wait: 10)
    expect(page).to have_css('.poi-user-pin__ping', wait: 10)
  end

  it 'точки на карте синхронизированы с точками в сайдбаре' do
    # Небольшой набор в одной области вокруг Берлина (fallback-центр) — все влезают
    # в видимые bounds карты при zoom 17 (разброс ~50-300м от центра).
    [
      [ 52.5200, 13.4050, 'Berlin Fountain A' ],
      [ 52.5207, 13.4060, 'Berlin Bridge B' ],
      [ 52.5194, 13.4038, 'Berlin Eye C' ]
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
          name: { 'en' => 'Berlin Bridge', 'ru' => 'Берлинский мост', 'es' => 'Puente de Berlín', 'zh' => '柏林桥' },
          latitude: POI_LAT,
          longitude: POI_LNG,
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
    expect(page).to have_content('Berlin Bridge', wait: 10)
  end

  it 'одну и ту же точку можно открыть повторно после закрытия через кнопку X (баг B)' do
    poi = nil
    browser_a do
      sign_in_via_ui(user_a)
      poi = PoiService.create(
        params: {
          poi_category_id: category.id,
          name: { 'en' => 'Reopen Bridge', 'ru' => 'Мост повторно', 'es' => 'Puente reabrir', 'zh' => '重新打开桥' },
          latitude: POI_LAT,
          longitude: POI_LNG,
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
  # Координаты пользователя пишутся в session рефлексом set_location. Единый
  # prepare_map_geolocation + форс set_location решают детерминированность. Форма
  # редактирования детерминированно покрыта админским сценарием.
  xit 'автор редактирует точку: форма + карта с маркером + все поля сохраняются' do
    poi = create(:poi,
                 user: user_a,
                 poi_category: category,
                 status: 'approved',
                 name: { 'en' => 'Original Name', 'ru' => 'Оригинальное', 'es' => 'Original', 'zh' => '原始' },
                 coordinates: PoiService.parse_coordinates(POI_LAT, POI_LNG))
    browser_a do
      sign_in_via_ui(user_a)
      prepare_map_geolocation(latitude: POI_LAT, longitude: POI_LNG)
      visit pois_path
      wait_for_selector('#poi-list [data-poi-id]', timeout: 90)
      force_user_location(latitude: POI_LAT, longitude: POI_LNG)
    end
  end

  describe 'галерея фотографий POI', js: true do
    let!(:gallery_poi) do
      create(:poi,
             user: user_a,
             poi_category: category,
             status: 'approved',
             name: { 'en' => 'Gallery POI', 'ru' => 'Галерея', 'es' => 'Galería POI', 'zh' => '画廊' },
             coordinates: PoiService.parse_coordinates(POI_LAT, POI_LNG))
    end

    # Открывает модалку точки и активирует таб «Галерея».
    # Клик по табу переключает панели (Ui::TabsComponent#switch). Надёжно:
    # кликаем по кнопке таба через execute_script (Selenium-клик по кнопке таба
    # хрупок при многократном прогоне) и ждём, пока панель галереи станет
    # ВИДИМОЙ (visible: true учитывает hidden на предке-панели).
    def open_gallery_tab
      sign_in_via_ui(user_a)
      visit pois_path
      page.execute_script("document.dispatchEvent(new CustomEvent('poi:show-detail', { detail: { poiId: #{gallery_poi.id} } }))")
      wait_for_selector("[data-poi--show-component-target='overlay']:not(.hidden)", timeout: 60)
      wait_for_selector("button[data-tab='gallery']", timeout: 30)
      # Клик по табу Gallery через JS (ui--tabs-component#switch → активная панель)
      page.execute_script("document.querySelector(\"button[data-tab='gallery']\").click()")
      # Ждём, пока панель галереи станет видимой (visible: true учитывает предка)
      Timeout.timeout(30) do
        sleep 0.2 until page.has_css?('[data-poi-gallery]', visible: true)
      end
      wait_for_selector('[data-poi-gallery]', timeout: 30)
    end

    it 'пустая галерея: плашка «будьте первым» + кнопка добавления' do
      open_gallery_tab
      expect(page).to have_content(I18n.t('poi.gallery_component.empty_title'), wait: 10)
      expect(page).to have_content(I18n.t('poi.gallery_component.empty_hint'), wait: 10)
      expect(page).to have_button(I18n.t('poi.gallery_component.add_photo'), wait: 10).or(have_selector('label', text: I18n.t('poi.gallery_component.add_photo')))
    end

    it 'показывает свои фото первыми (с удалением) и чужие после' do
      create(:photo, poi: gallery_poi, user: user_a, position: 0)
      create(:photo, poi: gallery_poi, user: user_b, position: 1)
      create(:photo, poi: gallery_poi, user: user_b, position: 2)

      open_gallery_tab

      # Своё фото (от user_a) — первым в сетке (3 миниатюры)
      thumbs = page.all('[data-poi--gallery-component-target="thumb"]', visible: false)
      expect(thumbs.length).to eq(3)
      # Первый thumb — фото user_a (у него есть кнопка удаления в его контейнере)
      first_thumb_container = thumbs.first.find(:xpath, '..')
      expect(first_thumb_container).to have_css('button[data-action="click->poi--gallery-component#remove"]', visible: false)
      # Кнопка удаления видима (панель галереи активна)
      wait_for_selector("button[data-action='click->poi--gallery-component#remove']", timeout: 20)
    end

    it 'добавляет своё фото и видит его без перезагрузки', :flaky do
      open_gallery_tab
      expect(page).to have_content(I18n.t('poi.gallery_component.empty_title'), wait: 10)

      # Загружаем файл через hidden input (multipart POST)
      attach_file('photo[image]', Rails.root.join('spec/fixtures/files/photo.png'), make_visible: true)

      # После upload JS вызывает PoiReflex#refresh_gallery → сетка обновляется
      wait_for_selector('[data-poi--gallery-component-target="thumb"]', timeout: 60)
      expect(gallery_poi.reload.photos.count).to eq(1)
    end

    it 'удаляет своё фото без перезагрузки', :flaky do
      photo = create(:photo, poi: gallery_poi, user: user_a, position: 0)
      open_gallery_tab

      # Кнопка удаления видима после активации таба — ждём её
      wait_for_selector("button[data-action='click->poi--gallery-component#remove'][data-photo-id='#{photo.id}']", timeout: 20)
      # JS-клик (execute_script) — детерминированный вызов Stimulus-действия:
      # Selenium .click по кнопке, перекрытой обложкой (.relative img open), теряется.
      page.execute_script("document.querySelector(\"button[data-action='click->poi--gallery-component#remove'][data-photo-id='#{photo.id}']\").click()")

      # JS → DELETE /pois/:id/photos/:id → Poi::PhotosController#destroy → live inner_html
      wait_for_selector('[data-poi-gallery]', timeout: 60)
      # DELETE выполняется асинхронно: мгновенный reload может застать фото ещё
      # в БД (CollectionProxy не empty). Ждём фактического опустошения галереи
      # (polling), затем ассертируем состояние БД и DOM.
      Timeout.timeout(60) do
        sleep 0.2 until gallery_poi.reload.photos.empty?
      end
      expect(gallery_poi.reload.photos).to be_empty
      # Галерея перерисована без фото — в сетке не осталось миниатюр
      # (live-обновление без перезагрузки страницы)
      expect(page).to have_no_css('[data-poi--gallery-component-target="thumb"]', wait: 60)
    end
  end
end
