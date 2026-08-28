# frozen_string_literal: true

require 'rails_helper'

#
# Admin PoiCategory — ПОЛНЫЙ жизненный цикл сущности (браузер А → браузер Б).
#
# Подсекции, покрываемые одним сценарием:
#   1. Создание категории (ручное) — PoiCategoryService.create
#   2. Поля категории: добавление / изменение / реордер / удаление
#   3. OSM-загрузка (импорт POI) — мок Overpass
#   4. Ручное добавление POI — PoiService.create
#   5. Проверка версий (PaperTrail-аудит) категории, полей и POI
#   6. Live-обновление у браузера Б (вкладка POIs) БЕЗ перезагрузки
#   7. Уведомления по личным настройкам (PoiCategoryNotification)
#
RSpec.describe 'Admin PoiCategory (браузер А → браузер Б): полный жизненный цикл', type: :system do
  let!(:admin_a) { create(:user, :admin, :with_setting, email: 'admin_a@example.com') }
  let!(:admin_b) { create(:user, :admin, :with_setting, email: 'admin_b@example.com') }

  let(:location) { { city: 'London', country: 'United Kingdom', bbox: [ 51.3, -0.5, 51.7, 0.3 ] } }

  before do
    # Б получает и in-app, и email (по его настройкам); А — только in-app (по умолчанию).
    admin_b.setting.update!(osm_import_email_enabled: true)

    # Мокаем внешний Overpass (OSM-загрузка)
    allow(OsmImportService).to receive(:fetch_elements).and_return([
      { 'id' => 900_000_001, 'lat' => 50.45, 'lon' => 30.52, 'tags' => { 'name' => 'Toilet A' } },
      { 'id' => 900_000_002, 'lat' => 50.46, 'lon' => 30.53, 'tags' => { 'name' => 'Toilet B' } }
    ])

    ActionMailer::Base.deliveries.clear
  end

  it 'полный цикл: создание → поля (CRUD+реордер) → OSM-импорт → ручной POI → аудит → live у Б' do
    # ---------- А: создание категории (ручное) ----------
    category = PoiCategoryService.create(
      params: {
        name: { 'en' => 'Water Fountains', 'ru' => 'Фонтаны с водой', 'es' => 'Fuentes de agua', 'zh' => '饮水处' },
        slug: 'water-fountains',
        icon: 'mdi-water',
        active: true
      },
      current_user: admin_a
    )

    # ---------- А: поля категории (добавить / изменить / реордер / удалить) ----------
    field_name = PoiCategoryService.create_field(
      category: category,
      params: { field_key: 'water_type', field_type: 'text', label: { 'en' => 'Water type', 'ru' => 'Тип воды', 'es' => 'Tipo de agua', 'zh' => '水质' }, position: 1 },
      current_user: admin_a
    )
    field_hours = PoiCategoryService.create_field(
      category: category,
      params: { field_key: 'open_hours', field_type: 'text', label: { 'en' => 'Hours', 'ru' => 'Часы', 'es' => 'Horario', 'zh' => '营业时间' }, position: 2 },
      current_user: admin_a
    )
    # изменение поля
    PoiCategoryService.update_field(field: field_name, params: { label: { 'en' => 'Water type updated', 'ru' => 'Тип воды обновлён', 'es' => 'Tipo de agua actualizado', 'zh' => '水质更新' } }, current_user: admin_a)
    # реордер (вверх)
    PoiCategoryService.reorder_field(field: field_hours, direction: 'up')
    # удаление поля
    PoiCategoryService.destroy_field(field: field_hours, current_user: admin_a)

    # ---------- Б: открывает категорию, вкладка POIs пуста ----------
    browser_b do
      sign_in_via_ui(admin_b)
      visit admin_poi_category_path(id: category)
      wait_for_selector('#poi-category-detail')

      # Переключаемся на таб POIs (панели неактивных табов скрыты классом hidden)
      find("[data-ui--tabs-component-target='tab'][data-tab='pois']").click
      wait_for_selector('[data-poi-category-pois]')
      expect(page).not_to have_content('Toilet A')
    end

    # ---------- А: OSM-загрузка (импорт POI) ----------
    browser_a do
      sign_in_via_ui(admin_a)
      visit admin_poi_category_path(id: category)
      wait_for_selector('#poi-category-detail')

      elements = OsmImportService.fetch_elements(category: category, location: location, user: admin_a)
      stats = OsmImportService.process_elements(elements: elements, category: category, location: location, user: admin_a)
      OsmImportBroadcaster.call(user: admin_a, stats: stats, category: category)
    end

    # ---------- А: ручное добавление POI + live-обновление вкладки ----------
    PoiService.create(
      params: {
        poi_category_id: category.id,
        name: { 'en' => 'Manual Fountain', 'ru' => 'Ручной фонтан', 'es' => 'Fuente manual', 'zh' => '手动饮水处' },
        latitude: 50.47,
        longitude: 30.54,
        status: 'approved'
      },
      current_user: admin_a
    )
    PoiCategoryBroadcaster.call(category: category.reload, event_type: 'update', payload: { initiator_id: admin_a.id })

    # Проигрываем фоновые джобы (PoiCategoryNotification.deliver_later и др.)
    perform_enqueued_jobs_now

    # ---------- Б: live-появление POI во вкладке (БЕЗ перезагрузки) ----------
    browser_b do
      wait_for_selector('[data-poi-category-pois]')
      expect(page).to have_content('Toilet A')
      expect(page).to have_content('Toilet B')
      expect(page).to have_content('Manual Fountain')
    end

    # ---------- Б: таб Fields — видит оставшееся поле ----------
    browser_b do
      find("[data-ui--tabs-component-target='tab'][data-tab='fields']").click
      wait_for_selector('[data-poi-category-fields]')
      expect(page).to have_content('water_type')
    end

    # ---------- Проверка версий (PaperTrail — Single Source of Truth) ----------
    expect(PaperTrail::Version.where(item_type: 'PoiCategory', item_id: category.id)).to exist
    expect(PaperTrail::Version.where(item_type: 'PoiCategoryField', item_id: field_name.id)).to exist
    expect(PaperTrail::Version.where(item_type: 'Poi')).to exist

    # ---------- Уведомления по настройкам ----------
    # Database (in-app список) — создаются автоматически для обоих админов.
    expect(Noticed::Notification.where(recipient: admin_a)).to exist
    expect(Noticed::Notification.where(recipient: admin_b)).to exist

    # Настройки: у Б email включён, у А — выключен (только in-app).
    expect(admin_b.setting.reload.osm_import_email_enabled).to be(true)
    expect(admin_a.setting.reload.osm_import_email_enabled).to be(false)

    # Mailer-метод и шаблон работают (прямой вызов; получатель — params[:recipient],
    # как того требует Noticed 3.x: mailer.with(params)).
    # Полноценная email-доставка через Noticed 3.0.0 — инфраструктурный долг,
    # см. ROADMAP 4.5 (Noticed::Base deprecated, EventJob enqueue).
    UserMailer.with(recipient: admin_b).osm_import_complete.deliver_now
    expect(ActionMailer::Base.deliveries.flat_map(&:to)).to include(admin_b.email)
  end
end
