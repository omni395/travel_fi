# frozen_string_literal: true

require 'rails_helper'

#
# POI Moderation Live (браузер А → браузер Б) — полный сценарий одобрения точки.
#
# Сценарий (шаги 1-6 из ТЗ):
#   1. Пользователь А нажимает «Add POI», открывает модалку, выбирает категорию,
#      заполняет форму и сохраняет → создаётся pending-точка → тост «появится
#      после одобрения».
#   2. Админ Б видит добавленную точку в админке ([data-admin-pois-list]).
#   3. Админ Б заходит на точку (#poi-detail).
#   4. Админ Б нажимает «Edit» → форма редактирования.
#   5. Админ Б меняет статус на approved через Dropdown и сохраняет форму.
#   6. Пользователь А БЕЗ перезагрузки видит появление точки на карте
#      (#poi-map-features) и в сайдбаре (#poi-list) — через live-конвейер
#      PaperTrail → VersionObserverJob → PoiBroadcaster → poi:reload-features.
#
# Ключевые аспекты (не подгоняем, воспроизводим ТЗ):
#   - Шаг 1 — ЧЕРЕЗ UI (кнопка Add POI + модалка + Dropdown категории + submit),
#     а не через прямой вызов PoiService.create.
#   - Шаг 6 — пользователь А остаётся НА ОТКРЫТОЙ КАРТЕ (bounds уже загружены,
#     _lastBoundsKey установлен первичной загрузкой) и видит точку БЕЗ перезагрузки.
#
RSpec.describe 'POI Moderation Live (одобрение через UI → пользователь live видит)', type: :system do
  # Координаты Лондона (fallback-центр карты и маркер-данные)
  POI_LAT = 51.5074
  POI_LNG = -0.1278
  # Название pending-точки, добавляемой через UI
  POI_NAME = 'London Moderation Target'

  let!(:user_a) { create(:user, :with_setting, email: 'poi_mod_author@example.com') }
  let!(:admin_b) { create(:user, :admin, :with_setting, email: 'poi_mod_admin@example.com') }
  let!(:category) { create(:poi_category) }

  #
  # Подготавливает браузер А к работе с картой: логинится, задаёт детерминированную
  # геолокацию на Лондон (CDP + стаб на новую навигацию), открывает карту и ждёт,
  # пока #poi-list наполнится approved-фоном (bounds загружены, _lastBoundsKey установлен).
  #
  def prepare_map_browser_a
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
    visit pois_path
    wait_for_selector('#poi-list [data-poi-id]', timeout: 90)
    wait_for_selector('#poi-map-features [data-poi-id]', timeout: 90)
  end

  #
  # ШАГ 1: пользователь А добавляет точку ЧЕРЕЗ UI — кнопка «Add POI» → модалка →
  # выбор категории (Dropdown) → заполнение name → submit (PoiReflex#create).
  #
  # @return [Poi] созданная pending-точка
  #
  def add_poi_via_ui
    before_id = Poi.maximum(:id) || 0

    # Кнопка «Add POI» (Ui::BtnComponent, data-action openAddPoi → диспатч poi:open-modal)
    click_on I18n.t('poi.map_component.add_poi')

    # Модалка формы создания (poi--form-component) появилась
    wait_for_selector('[data-controller="poi--form-component"]', timeout: 90)

    form = find('[data-controller="poi--form-component"]')
    within(form) do
      # Выбор категории через Ui::DropdownComponent (кнопка-триггер → меню)
      find('button[data-action="ui--dropdown-component#toggle"]').click
      find("div[data-action='click->poi--form-component#selectCategory'][data-category-id='#{category.id}']").click

      # Заполняем обязательное поле name
      fill_in 'poi[name]', with: POI_NAME

      # Координаты должны быть заполнены из геолокации (userLat/userLng → MapController).
      # Лондон: lat > 0, lng отрицательный (51.5074, -0.1278) — проверяем «не нуль».
      expect(find("input[name='poi[latitude]']", visible: false).value.to_f).not_to eq(0)
      expect(find("input[name='poi[longitude]']", visible: false).value.to_f).not_to eq(0)
    end

    # Submit формы (data-action submit->poi--form-component#handleSubmit → PoiReflex#create).
    # f.submit рендерит <input type="submit"> (не <button>).
    within(form) do
      find("input[type='submit']").click
    end

    # PoiReflex#create асинхронный (WebSocket) — ждём появления pending-точки в БД.
    poi = nil
    Timeout.timeout(30) do
      loop do
        poi = Poi.where('id > ?', before_id).order(:id).last
        break if poi
        sleep 0.2
      end
    end

    expect(poi.status).to eq('pending')
    expect(poi.user).to eq(user_a)
    poi
  end

  it 'шаг 1→6: А добавляет pending через UI → админ одобряет через Edit-форму → А live видит на карте и в сайдбаре' do
    # Approved-фон: карта/сайдбар А инициализируются детерминированно ДО добавления
    # pending-точки (чтобы #poi-list наполнился и bounds загрузились).
    browser_a do
      sign_in_via_ui(user_a)
      PoiService.create(
        params: {
          poi_category_id: category.id,
          name: { 'en' => 'London Approve Background', 'ru' => 'Фон', 'es' => 'Fondo', 'zh' => '背景' },
          latitude: POI_LAT,
          longitude: POI_LNG,
          status: 'approved'
        },
        current_user: user_a
      )
    end

    # Пользователь А открыт на карте (bounds загружены, _lastBoundsKey установлен)
    browser_a do
      prepare_map_browser_a
    end

    # ШАГ 1: добавляет pending-точку через UI (кнопка + модалка + форма)
    poi = nil
    browser_a do
      poi = add_poi_via_ui
    end

    # ШАГИ 2-5: админ Б через UI видит точку, заходит, Edit, меняет статус на approved, сохраняет.
    browser_b do
      sign_in_via_ui(admin_b)
      visit admin_pois_path
      wait_for_selector('[data-admin-pois-list]', timeout: 90)

      # ШАГ 2: админ видит добавленную пользователем точку в списке админки.
      find("tr[data-admin-poi-id='#{poi.slug}']").click

      # ШАГ 3: админ заходит на точку (просмотр).
      wait_for_selector('#poi-detail', timeout: 90)
      expect(page).to have_current_path(%r{\A/admin-panel/pois/[^/]+\z}, wait: 30)

      # ШАГ 4: нажимает «Edit» → форма редактирования.
      find('a[href*="edit=true"]', text: 'Edit').click
      wait_for_selector('[data-controller="admin--pois--poi--edit-component"]', timeout: 90)

      # ШАГ 5: меняет статус pending → approved через Dropdown и сохраняет форму.
      edit = find('[data-controller="admin--pois--poi--edit-component"]')
      within(edit) do
        # Исходный статус — pending (hidden input poi[status])
        expect(find("input[name='poi[status]'][type='hidden']", visible: false).value).to eq('pending')

        find('button[data-action="ui--dropdown-component#toggle"]', text: 'Pending').click
        find("div[data-action*='edit-component#selectStatus'][data-value='approved']", visible: false).click

        # selectStatus синхронно обновляет hidden poi[status] (как в admin/pois_spec.rb:156)
        expect(find("input[name='poi[status]'][type='hidden']", visible: false).value).to eq('approved')

        find("button[type='submit']").click
      end

      # Редирект на просмотр точки после сохранения (Admin::PoisReflex#update).
      wait_for_selector('#poi-detail', timeout: 90)
      expect(page).to have_current_path(%r{\A/admin-panel/pois/[^/]+\z}, wait: 30)
    end

    # Статус в БД — approved. Admin::PoisReflex#update выполняется серверно через
    # WebSocket (отдельный Puma-процесс), поэтому browser_b дожидается только
    # клиентского морфа, а commit в БД происходит асинхронно. Ждём (polling),
    # пока статус не станет approved — иначе гонка мгновенного reload.
    Timeout.timeout(30) do
      loop do
        break if poi.reload.status == 'approved'
        sleep 0.2
      end
    end
    expect(poi.status).to eq('approved')

    # Проигрываем асинхронный конвейер (PaperTrail → VersionObserverJob → PoiBroadcaster).
    perform_enqueued_jobs_now

    # ШАГ 6: пользователь А БЕЗ перезагрузки видит точку на карте и в сайдбаре.
    browser_a do
      # НЕ делаем visit — проверяем live-появление в уже открытой карте.
      wait_for_selector("#poi-map-features [data-poi-id='#{poi.id}']", timeout: 90)
      expect(page).to have_css("#poi-map-features [data-poi-id='#{poi.id}']", visible: false)

      wait_for_selector("#poi-list [data-poi-id='#{poi.id}']", timeout: 90)
      expect(page).to have_css("#poi-list [data-poi-id='#{poi.id}']", visible: false)
    end
  end
end
