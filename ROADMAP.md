# Travel Fi — Product Roadmap

> Единый план по **секциям приложения**: что сделано, что нет, хотелки и баги — в каждом блоке.
> **Статусы секций:** `✅ Сделано` · `🟡 Частично` · `🔴 В планах` · `🧪 Тесты`
> **Статусы пунктов:** `✅` выполнено · `🔴` в планах (хотелка) · `⚠️` баг
> Архитектура и инструкции — в [`README.md`](README.md:1) и `.roo/rules/` (здесь не дублировать).

---

## 0. Легенда и правила ведения

- **Секции = страницы приложения** (USER SECTION и ADMIN SECTION). Горизонтальные слои — сквозная инфраструктура, на них ссылаются секции.
- **В каждой секции** 3 блока:
  - **Сделано** — пункты помечены `✅`
  - **Хотелки** — пункты помечены `🔴` (в планах)
  - **Баги** — пункты помечены `⚠️`
- **Маршруты:** профиль юзера — `/:slug` (НЕ `/admin`), админка — `/admin-panel` (см. [`config/routes.rb`](config/routes.rb:36)).
- **Цепочка (Database-Triggered Workflow):** Controller/Reflex → Service (Pundit + save! в транзакции) → PostgreSQL + PaperTrail → VersionObserverJob → Broadcaster (inner_html) → CableReady → ActionCable (SolidCable) → DOM.

---

## 1. Карта секций приложения

```
Travel Fi
├── 👤 USER SECTION          (/:locale/)
│   ├── 2.1 Landing          (/)               🔴 заглушка
│   ├── 2.2 POI Map          (/pois)           🟡
│   ├── 2.3 User Profile     (/:slug)          🟡
│   ├── 2.4 User Settings    (/:slug/settings) ✅
│   └── 2.5 Auth pages       (/users/*)        ✅
├── 🛠 ADMIN SECTION         (/:locale/admin-panel)
│   ├── 3.1 Dashboard        (/admin-panel)          ✅
│   ├── 3.2 Users            (/admin-panel/users)    ✅
│   ├── 3.3 PoiCategories    (/admin-panel/poi_categories)  🟡
│   ├── 3.4 Pois             (/admin-panel/pois)     🟡
│   ├── 3.5 Settings         (/admin-panel/settings) ✅
│   └── 3.6 Contract Mgmt    🔴 (в планах)
├── 4. Горизонтальные слои
│   ├── 4.1 Auth & Roles     ✅
│   ├── 4.2 Gamification & Web3  🟡/🔴
│   ├── 4.3 Realtime-инфра   ✅
│   ├── 4.4 Audit            ✅
│   ├── 4.5 Notifications    ✅
│   ├── 4.6 i18n / UI        ✅ (1 баг sidecar)
│   ├── 4.7 PWA / Devices    🟡
│   └── 4.8 CI / Tests / Production  🟡/🔴
└── 5. ERD + потоки данных
```

---

## 2. 👤 USER SECTION

### 2.1 Landing (главная)

**Маршрут:** `/` ([`PagesController#index`](app/controllers/pages_controller.rb:10))

**Цепочка:** PagesController → view (залогиненный редиректится на `/pois` через `session[:redirected_to_map]`)

**Компоненты:** [`Ui::NavbarComponent`](app/components/ui/navbar_component.rb:1) (общий layout [`app/views/layouts/application.html.erb`](app/views/layouts/application.html.erb:47))

**Статус:** 🔴 **Не сделано** — [`app/views/pages/index.html.erb`](app/views/pages/index.html.erb:1) содержит заглушку («тест»).

**Сделано:**
- ✅ Роут и контроллер страницы
- ✅ Редирект залогиненного на карту (однократно за сессию)

**Хотелки:**
- 🔴 Полноценный лендинг: hero + преимущества + CTA «Открыть карту»
- 🔴 Блок популярных категорий POI (из `PoiCategory.active`)
- 🔴 Статистика сообщества (POI, города, участники)
- 🔴 FAQ / Как это работает
- 🔴 Подвал (футер): ссылки, локали, PWA-установка

**Баги:**
- ⚠️ —

### 2.2 POI Map (карта + список + модалка)

**Маршруты:** `/pois` (index/new/create/update) — [`PoisController`](app/controllers/pois_controller.rb:12)

**Цепочка:** `PoisController` (index/просмотр) → [`PoiReflex`](app/reflexes/poi_reflex.rb:16) (load_pois_in_bounds, load_more_pois, filter_by_categories, apply_filters, reset_filters, show_detail, show_detail_modal, edit_poi, create_comment, reverse_geocode, set_location, show_geolocation_toast) → [`PoiService`](app/services/poi_service.rb:12) → PostGIS (`within_bounds`/`within_meters`) → [`PoiBroadcaster`](app/broadcasters/poi_broadcaster.rb:12) / `ToastBroadcaster` → `UserChannel` / `AdminChannel`

**Компоненты:** [`Poi::MapComponent`](app/components/poi/map_component.rb:1) (OpenLayers 10), `Poi::ListItemComponent`, `Poi::ShowComponent`, `Poi::FormComponent`, `Poi::FiltersComponent`, `Poi::CommentsComponent`, `Ui::SidebarComponent`. Модалки: `Poi::DetailsComponent`, `Poi::GalleryComponent`, `Poi::RatingsComponent` (частично/заглушки).

**Статус:** 🟡 Частично

**Сделано:**
- ✅ Карта OpenLayers 10 + кластеризация + PostGIS-запросы по границам
- ✅ Сайдбар со списком видимых POI + «Load more» (пагинация по offset)
- ✅ Фильтры по категориям и поиск по JSONB name/description (Ransack + ILIKE)
- ✅ Карточка POI в модалке (шапка + табы)
- ✅ Форма создания/редактирования POI + мини-карта + обратный геокодинг (Nominatim)
- ✅ Галерея фото через `PhotoService` (ActiveStorage)
- ✅ Проксимити-проверка 100м для комментариев/редактирования (`check_proximity!`, `PoiCommentPolicy`)

**Хотелки:**
- 🔴 `PoiRating` — 5-звёздная система + агрегация в `poi.rating`
- 🔴 Комментарии: live для всех + threaded-ответы + proximity 100м
- 🔴 Галерея: сетка + lightbox/слайдер
- 🔴 OSRM: построение маршрута к POI + линия на карте
- 🔴 Offline-режим (PWA): тайлы + список (IndexedDB)

**Баги:**
- ✅ OSM-импорт: вкладка списка обновляется по мере добавления и при закрытии — исправлено: убран `morph`-дубль карточки в `OsmImportBroadcaster`, добавлен инкрементальный `inner_html [data-poi-category-pois]` каждые 10 импортов; подтверждено `poi_category_spec` (0 failures)
- ✅ После импорта/создания POI не появлялись на карте — исправлено: fallback-загрузка маркеров в `map_component_controller.js` (если `postrender` OpenLayers не срабатывает — ретрай `_loadPoisInBounds`); `poi:reload-features` → перезапрос с сервера; system-тест `pois_map_spec` (0 failures)
- ⚠️ Reverse geocoding не всегда заполняет city/country/address
- ⚠️ Валидация координат: без координат — скрыть кнопку + сообщение
- ⚠️ Загрузка фото (бинарники через StimulusReflex) → HTTP/multipart + `PhotoService.attach_photos`
- ⚠️ Мини-карта формы не инициализируется после `cable_ready.inner_html`
- ✅ Комментарии: базовый `PoiCommentBroadcaster` + ветка `PoiComment` в `VersionObserverJob` (live для ВСЕХ — хотелка 2.2); proximity-check 100м исправлен — `within_range?` возвращал строку `"t"/"f"` (антифрод всегда проходил), теперь Boolean + SRID 4326, `check_proximity!`/`PoiCommentPolicy` корректны
- ✅ Награды TFT за создание POI/комментарий не начислялись — `GamificationService.award!(:poi_create/:comment_create)` добавлены в `PoiService` (суммы из `config/gamification.yml`)
- ✅ Создание POI с карты падало `PolicyScopingNotPerformedError` — `skip_after_action :verify_policy_scoped` в `PoisController`
- ✅ Сломанная fallback-страница `new` (`Poi::AddFormComponent` не существовал) — страница убрана, создание через модалку `Poi::FormComponent`, create→JSON 422, fetch-сабмит формы
- ✅ `PoiReflex#filter_by_categories` NameError (`bounds`→`params`) — исправлено
- ✅ `PoiBroadcaster` использовал `morph` — заменён на `inner_html`
- ⚠️ Карточка POI: полировка UI (фокус-трап, aria, скролл-блокировка)

### 2.3 User Profile (профиль пользователя)

**Маршрут:** `/:slug` (show/edit) — [`UsersController`](app/controllers/users_controller.rb:13)

**Цепочка:** `UsersController` (show/edit, рендер) + [`UserReflex`](app/reflexes/user_reflex.rb:10) (update_profile) → [`UserService`](app/services/user_service.rb:15) (name + avatar через `PhotoService`) → [`UserBroadcaster`](app/broadcasters/user_broadcaster.rb:12) → `user_<id>` (inner_html по обёртке `[data-user-profile-id]`)

**Компоненты:** [`Users::ProfileComponent`](app/components/users/profile_component.rb:11), [`Users::FormComponent`](app/components/users/form_component.rb:1), табы `Ui::TabsComponent` (Activity / Wallet / Audit Log).

**Статус:** 🟡 Частично

**Сделано:**
- ✅ Отображение профиля (аватар, имя, email, статус, баланс TFT, кошелёк, бейджи, роли)
- ✅ Редактирование имени + аватар (через Broadcaster)
- ✅ Настройки уведомлений на `/:slug/settings` (см. 2.4)
- ✅ Pundit: свой профиль или админ

**Хотелки:**
- 🔴 Live-переключение табов (активность/аудит) без перезагрузки
- 🔴 Секция уровней/бейджей геймификации
- 🔴 Личная статистика активности (POI, комментарии, баллы)

**Баги:**
- ✅ `User#badges` — исправлен (метод по `badge_ids` через `gamification.yml`), профиль больше не падает
- ✅ Live-обновление имени профиля через `UserBroadcaster` — исправлено: рендер `ProfileComponent` из job фиксирует `I18n.with_locale(default)` (No route matches устранён), `cable_controller.js` применяет CableReady-операции по одной (per-op try/catch). Live-e2e не покрыт (в `user_lifecycle_spec` — проверка через `visit`)
- ⚠️ Табы (активность/аудит) в профиле — переключение не live
- ✅ Автоматика `inactive` реализована: `UserInactivityJob` (active без активности 6+ мес → inactive) + `UserService.mark_inactive_old_users` + запись в `config/recurring.yml`; unit-покрытие `user_service_spec`/`user_inactivity_job_spec`
- ⚠️ Неподтверждённая верификация → определить поведение (сброс/флаг/повтор)

### 2.4 User Settings (настройки пользоателя)

**Маршрут:** `/:slug/settings` — [`Users::SettingsController#show`](app/controllers/users/settings_controller.rb:10)

**Цепочка:** `SettingsReflex#update` ([`app/reflexes/settings_reflex.rb`](app/reflexes/settings_reflex.rb:5)) → [`SettingService.update`](app/services/setting_service.rb:3) → [`SettingBroadcaster`](app/broadcasters/setting_broadcaster.rb:11) → `user_<id>` (toast)

**Компоненты:** [`Settings::FieldComponent`](app/components/settings/field_component.rb:1) (в т.ч. админ-набор через `admin/settings`)

**Статус:** ✅ Сделано (user-facing часть)

**Сделано:**
- ✅ Переключатели событий (in-app / email / push) для пользователя
- ✅ Автосохранение через Reflex + toast

**Хотелки:**
- 🔴 Верификация email/push перед включением каналов
- 🔴 Группировка и поиск по событиям

**Баги:**
- ⚠️ —

### 2.5 Auth pages (аутентификация)

**Маршруты:** Devise `/users/*` (sessions/registrations/confirmations/passwords/unlocks) + Google OAuth (`/users/auth/google_oauth2`) — [`config/routes.rb`](config/routes.rb:19)

**Цепочка:** Devise-контроллеры (`users/*`) → `UserService.handle_google_oauth` ([`app/services/user_service.rb`](app/services/user_service.rb:34)) → `Setting.create_for_user` + `WalletService.create_hidden_wallet` (OAuth сразу) + welcome-токены (`award_registration_bonus!`)

**Статус:** ✅ Сделано (базовое)

**Сделано:**
- ✅ Регистрация/логин/подтверждение/восстановление пароля (Devise + confirmable + lockable)
- ✅ Google OAuth (OmniAuth) + аватар через `PhotoService`
- ✅ Роли по умолчанию (:user), реферальный код при регистрации
- ✅ **Скрытый custodial-кошелёк:** email — после подтверждения, OAuth — сразу (`WalletService.create_hidden_wallet`, EIP-55, private key зашифрован)
- ✅ Welcome-токены TFT (10) при регистрации + реферальные бонусы (15/5) через `award_registration_bonus!`

**Хотелки:**
- 🔴 EIP-2771: sponsored-транзакции + `ContractService` on-chain отправка токенов на кошелёк

**Баги:**
- ✅ OAuth-флоу покрыт unit-тестом (`UserService.handle_google_oauth` в `user_service_spec`: роль, статус active, настройки, кошелёк, welcome-токены, идемпотентность); реферальная логика через OAuth — хотелка (в OAuth-флоу нет поля рефкода)
- ✅ Смена статусов / подтверждение email / soft-delete — подтверждено `user_lifecycle_spec` (0 failures); автоматика `inactive` (recurring-джоб) — см. баг 2.3

---

## 3. 🛠 ADMIN SECTION (`/admin-panel`)

> Layout [`app/views/layouts/admin.html.erb`](app/views/layouts/admin.html.erb:43): Navbar + Sidebar + контент + тосты. Канал: `AdminChannel` (admin/moderator). База: [`Admin::BaseController`](app/controllers/admin/base_controller.rb:11).

### 3.1 Dashboard (дашбоард)

**Маршрут:** `/admin-panel` — [`Admin::DashboardController#index`](app/controllers/admin/dashboard_controller.rb:9)

**Цепочка:** `Admin::DashboardReflex` (refresh/refresh_stats) + `Admin::DashboardService.stats` → [`Admin::DashboardBroadcaster`](app/broadcasters/admin/dashboard_broadcaster.rb:3) (morph `[data-admin-*]`) → `AdminChannel`

**Компоненты:** [`Admin::DashboardComponent`](app/components/admin/dashboard_component.rb:15), `Admin::Dashboard::StatCardComponent`, `Ui::BreadcrumbsComponent`

**Статус:** ✅ Сделано (базовое)

**Сделано:**
- ✅ Карточки статистики (total/active/restricted/pending) с live-обновлением
- ✅ Последние пользователи + последние активности (из `versions`)
- ✅ Авторизация: admin/moderator

**Хотелки:**
- 🔴 Чарты: Chartkick/Groupdate (активность, гео, категории, просмотры)
- 🔴 GA/GTM-интеграция
- 🔴 KPI по POI (pending/approved/rejected), импортам OSM, комментариям

**Баги:**
- ✅ `new_users_today` — исправлено: `Admin::DashboardService.stats` возвращает `total_users/active_users/suspended_users/new_users_today` (совпадает с `DashboardComponent`); `new_users_today` = зарегистрированные сегодня (не pending); `dashboard_service_spec` обновлён
- admin_channel.js:30 [AdminChannel] skip morph (selector not found): [data-admin-stats-total-users], при этом селектор вызывается когда я нахожусь на другой странице.

### 3.2 Users (пользователи)

**Маршруты:** `/admin-panel/users` (index/show/update) — [`Admin::UsersController`](app/controllers/admin/users_controller.rb:12)

**Цепочка:** [`Admin::UsersReflex`](app/reflexes/admin/users_reflex.rb:11) (update/destroy/filter/sort/reset_filters) → [`Admin::UserService`](app/services/admin/user_service.rb:19) → [`Admin::UserBroadcaster`](app/broadcasters/admin/user_broadcaster.rb:15) (inner_html таблицы `[data-admin-users-list]`, prepend, remove, audit, dispatch_event) → `AdminChannel`

**Компоненты:** `Admin::Users::TableComponent`, `Admin::Users::RowComponent`, `Admin::Users::User::ShowComponent`, `EditComponent`, `ActivityComponent`, `WalletComponent`, `AuditLogComponent` (`Ui::AuditEntryComponent`), `Ui::FiltersComponent`, `Ui::TabsComponent`

**Статус:** ✅ Сделано (CRUD + live)

**Сделано:**
- ✅ Список + поиск + фильтр по статусу (включая deleted) + сортировка + пагинация (pagy)
- ✅ Детальная страница: профиль + табы (Activity / Wallet / Audit Log)
- ✅ Редактирование (name/email/status/role) + мягкое удаление (статус `deleted`, запись не удаляется)
- ✅ Live: prepend нового юзера + обновление таблицы (inner_html) через `AdminChannel`; deleted скрыт в «All», виден через фильтр статуса

**Хотелки:**
- 🔴 Массовые операции (батч-статус, батч-роль)
- 🔴 Экспорт списка (CSV)

**Баги:**
- ✅ Управление ролями синхронизировано: форма шлёт `role_id` (одна роль), `Admin::UsersController#user_params` permit `role_id` ↔ `Admin::UserService#update_user_roles!`
- тосты не отображаются при изменении юзера. 
- потерялся аватар пользователя (логин через гугл оауз)


### 3.3 PoiCategories + поля + OSM-импорт

**Маршруты:** `/admin-panel/poi_categories` (index/show/new/create/update) — [`Admin::PoiCategoriesController`](app/controllers/admin/poi_categories_controller.rb:11)

**Цепочка:** [`Admin::PoiCategoriesReflex`](app/reflexes/admin/poi_categories_reflex.rb:10) (create/update/filter/import_from_osm/pois_page/audit_page) + [`Admin::PoiCategoryFieldsReflex`](app/reflexes/admin/poi_category_fields_reflex.rb:9) (create/update/destroy/reorder) → [`PoiCategoryService`](app/services/poi_category_service.rb:11) + [`OSMImportService`](app/services/osm_import_service.rb:1) → [`PoiCategoryBroadcaster`](app/broadcasters/poi_category_broadcaster.rb:18) / [`OsmImportBroadcaster`](app/broadcasters/osm_import_broadcaster.rb:11) → `AdminChannel` / `user_<id>`

**Компоненты:** `Admin::PoiCategories::TableComponent`, `RowComponent`, `Admin::PoiCategories::PoiCategory::ShowComponent`, `EditComponent`, `FieldsListComponent`, `FieldFormComponent`, `PoisListComponent`, `AuditLogComponent`, `OSMImportComponent`, `Ui::AuditEntryComponent`

**Статус:** ✅ Сделано (эталон секции)

**Сделано:**
- ✅ CRUD категорий (JSONB name/description на 4 локали, slug, icon, position, active)
- ✅ Динамические поля категорий (создание/обновление/удаление/реордер через `update!` для аудита)
- ✅ Обратный геокодинг в форме POI (Nominatim)
- ✅ OSM-импорт: fetch + процесс с прогрессом (`OsmImportBroadcaster.progress`)
- ✅ Единая лента аудита категории + полей (включая удалённые через `parse_version_object`)
- ✅ **Live вкладка POIs:** после импорта `OsmImportBroadcaster` вызывает `PoiCategoryBroadcaster` → `inner_html [data-poi-category-pois]` (новые POI появляются без перезагрузки)
- ✅ **Live карта:** событие `poi:reload-features` теперь вызывает `_loadPoisInBounds()` (перезапрос с сервера) — новые POI попадают на карту и в сайдбар
- ✅ **Уведомления по настройкам:** единая `PoiCategoryNotification` (мультикаст инициатор + админы), персональные Setting-фильтры (in-app/email/push); колонки `osm_import_*` в `settings`

**Хотелки:**
- 🔴 DAO-верификация категорий
- 🔴 Импорт OSM в фоне через SolidQueue (сейчас синхронно в Reflex)

**Баги:**
- ⚠️
 - отвалилась вкладка аудит лог. не находится селектор:
      admin_channel.js:30 [AdminChannel] skip morph (selector not found): [data-audit-log]

### 3.4 Pois (точки интереса)

**Маршруты:** `/admin-panel/pois` (index/show/new/create/update) — [`Admin::PoisController`](app/controllers/admin/pois_controller.rb:11)

**Цепочка:** [`Admin::PoisReflex`](app/reflexes/admin/pois_reflex.rb:11) (update/create/change_status/destroy/filter/sort/reset_filters) → [`PoiService`](app/services/poi_service.rb:12) → [`PoiBroadcaster`](app/broadcasters/poi_broadcaster.rb:12) → `AdminChannel` / `UserChannel`

**Компоненты:** `Admin::Pois::TableComponent`, `RowComponent`, `Admin::Pois::Poi::ShowComponent`, `EditComponent`, `Ui::FiltersComponent`, `Ui::TabsComponent`, `Poi::MapComponent`

**Статус:** 🟡 Частично

**Сделано:**
- ✅ Список + поиск + фильтры (статус/категория) + сортировка + пагинация
- ✅ Детальная страница: Details / Map / Audit Log
- ✅ Модерация статуса (pending/approved/rejected/archived)
- ✅ Мультиязычные JSONB name/description + dynamic fields в metadata

**Хотелки:**
- 🔴 Карточка POI по единому паттерну: табы Details/Comments/Ratings/Gallery/Audit
- 🔴 Массовая модерация

**Баги:**
- ✅ `Admin::PoisReflex#update`/`change_status` — переведены на `morph :nothing` + тост (эталон); зона `#poi-detail` рендерится `PoiBroadcaster` (AdminChannel, live у ВСЕХ админов, не только инициатора)
- ✅ Бейджи `first_poi`/`contributor` не работали (`User` без `has_many :pois`) — исправлено в `User`
- ✅ После создания POI через админку точка появляется на карте — `PoiBroadcaster` шлёт `poi:reload-features` + fallback-загрузка маркеров карты
- ⚠️ Галерея: просмотр `Poi#photos` (сетка + lightbox) не реализован

### 3.5 Settings (настройки уведомлений админа)

**Маршрут:** `/admin-panel/settings` (resource :settings, only: show) — [`Admin::SettingsController`](app/controllers/admin/settings_controller.rb:1)

**Цепочка:** `SettingsReflex#update` → `SettingService.update` → `SettingBroadcaster` → `user_<id>` (админ как обычный юзер)

**Компоненты:** [`Settings::FieldComponent`](app/components/settings/field_component.rb:1), `Ui::AuditEntryComponent`, `Ui::BreadcrumbsComponent`

**Статус:** ✅ Сделано

**Сделано:**
- ✅ Все типы событий (включая админские: new_registration, user_updated_by_admin и т.д.)
- ✅ Автосохранение + тост + лента аудита Settings

**Хотелки:**
- 🔴 Разделение уведомлений админских событий по ролям (Rolify-фильтрация)

**Баги:**
- ⚠️ —

### 3.6 Contract Mgmt (управление контрактами)

**Статус:** 🔴 В планах (см. слой 4.2)

**Хотелки:**
- 🔴 Mint/rate/pause/награды через админку
- 🔴 `ContractSnapshot` вместо эфемерного `Rails.cache` в `ContractService.detect_changes_for_contract`

**Баги:**
- ⚠️ —

---

## 4. Горизонтальные слои (сквозные)

### 4.1 Auth & Roles
**Статус:** ✅ Сделано
- ✅ Devise (email + confirmable + lockable), Google OAuth (OmniAuth), Bcrypt
- ✅ Pundit-политики: `UserPolicy`, `PoiPolicy`, `PoiCommentPolicy`, `PoiCategoryPolicy`, `SettingPolicy`, `Admin::UserPolicy`, `Admin::DashboardPolicy`, `AdminPolicy`
- ✅ Rolify: роли `admin` / `moderator` / `user`; `AdminChannel` — admin/moderator
- ✅ **Статусы юзера (чистая модель):** `pending` (зарегистрирован, email не подтверждён) → `active` (после подтверждения) → `inactive` (неактивность 6+ мес, автоматика — `UserInactivityJob` recurring); `suspended`/`banned` (админ), `deleted` (мягкое удаление — запись не удаляется, защита от повторных регистраций; админу виден через фильтр статуса). Пользователей физически НЕ удаляем никогда.

### 4.2 Gamification & Web3
**Статус:** 🟡 Токен-модель ✅ / 🔴 EIP-2771
- ✅ **ТОКЕННАЯ МОДЕЛЬ:** награды — токены TFT (`UserReward`, off-chain леджер), `User#token_balance`; `GamificationService` (`award!`, `award_referral!`, `badge_key`, `check_badges!`); бейджи — `gamifications` (event_type badge); welcome 10 / referral 15+5 TFT. Баллы и уровни удалены (был баг `user.level` — снят).
- ✅ **Custodial-кошелёк:** модель `Wallet` (`kind: custodial/external`), `WalletService.create_hidden_wallet` (EIP-55, шифрование private key `MessageEncryptor`), генерация на Ruby без новых гемов ([`Crypto::Ethereum`](lib/crypto/ethereum.rb:1) — OpenSSL secp256k1 + keccak256 + EIP-55). Email — после подтверждения, OAuth — сразу.
- ✅ Контракты ERC-20 TFT (`travel-fi.sol`) — **задеплоены и верифицированы** (Base Sepolia, см. `.env`); on-chain отправка через [`ContractService`](app/services/contract_service.rb:22)
- 🔴 EIP-2771 forwarder + admin hot-wallet; Jetton TON + bridge
- 🔴 Token Spend (premium-фичи), Contract Mgmt в админке

### 4.3 Realtime-инфраструктура
**Статус:** ✅ Сделано
- ✅ StimulusReflex + CableReady + SolidCable (database-backed ActionCable), каналы `AdminChannel`/`UserChannel`
- ✅ SolidQueue + SolidQueueDashboard (mount `/solid-queue`), SolidCache (инфраструктура; кэш в коде отключён)

### 4.4 Audit (PaperTrail)
**Статус:** ✅ Сделано
- ✅ PaperTrail (Single Source of Truth) → [`VersionObserverJob`](app/jobs/version_observer_job.rb:12) (ветки `handle_<model>_update`) → Broadcasters
- ✅ [`PaperTrailAuditService`](app/services/paper_trail_audit_service.rb:1), `UserAuditLogger`, `UserActivityService`
- ✅ Правило: `update!`/`save!` (версии → broadcast), `update_all` запрещён для данных с аудитом

### 4.5 Notifications (Noticed)
**Статус:** 🟡 Частично (in-app/database ✅; email — долг)
- ✅ In-app (action_cable) и database-уведомления работают (включая `PoiCategoryNotification`)
- ✅ Фильтрация каналов через `Setting` (`setting_field_enabled?`), Web push [`web_push.rb`](app/notifications/noticed/delivery_methods/web_push.rb:1)
- ✅ **Noticed 3.0.0 миграция выполнена:** `ApplicationNotification < Noticed::Event`, `required_param` вместо `param`, `deliver_by :database` удалён (записи сохраняются автоматически), `WebPush < Noticed::DeliveryMethod`. `action_cable` (UserChannel) настроен.
- ⚠️ **Долг email:** доставка через `mailer.with(params)` (получатель `params[:recipient]`) — проверить в реальном прогоне; `EventJob` требует `perform_enqueued_jobs` в цикле.

### 4.6 i18n / UI (ViewComponents)
**Статус:** ✅ Сделано
- ✅ 4 локали (en/ru/es/zh); sidecar ViewComponents (rb + html + css + controller.js + 4 yml)
- ✅ Только зелёно-голубая палитра Tailwind (emerald/teal/sky), иконки MDI, запрет partials
- ✅ UI-библиотека: `Ui::CardComponent`, `BtnComponent`, `DropdownComponent`, `TabsComponent`, `BadgeComponent`, `AvatarComponent`, `TooltipComponent`, `BreadcrumbsComponent`, `PaginationComponent`, `ConfirmDialogComponent`, `ToastComponent`, `SidebarComponent`, `NavbarComponent`, `FiltersComponent`, `AuditEntryComponent`, `ClipboardComponent`, `HamburgerComponent`
- ✅ **Sidecar [`Ui::DateComponent`](app/components/ui/date_component.rb:1) дозаполнен** (css + controller.js) — баг закрыт

### 4.7 PWA / Devices
**Статус:** 🟡 Частично
- ✅ Манифест + service worker ([`app/views/pwa/`](app/views/pwa/manifest.json.erb:1))
- 🟡 Иконки установки приложения (логотип/фон) — есть, требуется доработка
- 🔴 Offline: тайлы карты, offline-список (IndexedDB), offline GPX/CSV, push

### 4.8 CI / Tests / Production
**Статус:** 🟡/🔴
- 🟡 CI: brakeman/bundler-audit/rubocop/yarn audit — есть; **rspec в [`config/ci.rb`](config/ci.rb:1) добавить**
- 🔴 Production-деплой: [`config/deploy.yml`](config/deploy.yml:1) — заглушки `192.168.0.1`/`localhost:5555`; домен, SMTP, force_ssl
- 🟡 Performance: tile caching, PostGIS-оптимизация, SolidCable clustering, GeoJSON-кэш

---

## 5. Связи сущностей + потоки данных

### 5.1 Связи сущностей (таблица)

| # | Модель | Связь | Модель | Описание |
|---|--------|-------|--------|----------|
| 1 | `User` | 1 — 1 | `Setting` | у каждого юзера одна строка настроек уведомлений |
| 2 | `User` | 1 — N | `Gamification` | баллы и бейджи юзера |
| 3 | `User` | M — N | `Role` | роли через таблицу `users_roles` (Rolify) |
| 4 | `User` | 1 — N | `Poi` | юзер — создатель точек |
| 5 | `User` | 1 — N | `PoiComment` | юзер — автор комментариев |
| 6 | `User` | 1 — N | `Wallet` | custodial (наш) / external (свой) кошелёки |
| 7 | `PoiCategory` | 1 — N | `PoiCategoryField` | категория определяет набор динамических полей |
| 8 | `PoiCategory` | 1 — N | `Poi` | категория содержит точки |
| 9 | `Poi` | 1 — N | `PoiComment` | комментарии к точке (self-join `parent_id` — ответы) |
| 10 | `Poi` | 1 — N | `Photo` | галерея фото (ActiveStorage) |
| 11 | `Poi` | 1 — N | `PoiRating` | 5-звёздные оценки (🔴 в планах) |
| 12 | `Poi` | N — 1 | `PoiCategory` | каждая точка принадлежит одной категории |
| 13 | `Poi` | N — 1 | `User` | у каждой точки есть создатель |
| 14 | *(все)* | — | `PaperTrail::Version` | аудит изменений всех моделей с `has_paper_trail` |

### 5.2 Эталонная цепочка обновлений (Database-Triggered Workflow)

```
Браузер (Stimulus: клик/ввод)
   │  this.stimulate("XxxReflex#action", params) — RPC через WebSocket
   ▼
Reflex (morph :nothing, deep_symbolize_keys, authorize_with_pundit!)
   │  только делегирует в Service
   ▼
Service (Pundit + Model.save!/update! внутри транзакции)
   ▼
PostgreSQL + PaperTrail → запись Version
   ▼
VersionObserverJob (SolidQueue) — ветка handle_<model>_update
   ▼
Broadcaster (helpers.render + cable_ready.inner_html по селекторам-обёрткам)
   ▼
CableReady + ActionCable (SolidCable) → стрим user_N / AdminChannel
   ▼
DOM обновляется точечно у всех подписанных браузеров
```

### 5.3 Потоки данных между секциями

- **User Profile ↔ Admin Users:** изменение юзера → PaperTrail → `VersionObserverJob#handle_user_update` → `Admin::UserBroadcaster` (AdminChannel) + `UserBroadcaster` (user_N, только если не админ-инициатива) + `UserProfileNotification` (Noticed, фильтр по `Setting`).
- **POI Map ↔ Admin Pois:** создание/изменение POI → `VersionObserverJob#handle_poi_update` → `PoiBroadcaster` (список + тост + `poi:reload-features` → карта) + `Admin::DashboardBroadcaster.broadcast_stats_update`.
- **PoiCategories ↔ POI Map:** изменение категории/полей → `PoiCategoryBroadcaster` (AdminChannel, карточка/поля/POI/аудит); видимость POI на карте зависит от `poi_categories.active` (scope `Poi.visible`).
- **OSM-импорт ↔ POI Map:** `Admin::PoiCategoriesReflex#import_from_osm` → `OsmImportBroadcaster` (прогресс/результат в user_N) + `poi:reload-features` → перезагрузка маркеров карты.
- **Settings ↔ Notifications:** `SettingsReflex` → `SettingService` → `SettingBroadcaster` (user_N); `Setting`-фильтры применяются при рассылке Noticed.

---

## 6. 🧪 ТЕСТЫ

### Принцип (эталон)
Один тест на сценарий = **«браузер А → браузер Б»**: А выполняет действие (Reflex/Service → save! → PaperTrail → VersionObserverJob → Broadcaster → CableReady) → Б видит live-обновление БЕЗ перезагрузки + уведомления по своим настройкам.

### Инфраструктура
- ✅ RSpec + FactoryBot + PostGIS; **Capybara + Cuprite** (headless Chrome) для двух сеансов
- ✅ DatabaseCleaner (system — truncation, остальные — transaction); WebMock (мок Overpass); ActiveJob `:test`
- ✅ ActionCable в тестах — `solid_cable` (live между браузерами), тестовая cable-БД `travel_fi_test_cable`
- ✅ Хелперы [`spec/support/system_helpers.rb`](spec/support/system_helpers.rb:1): `browser_a`/`browser_b`, `sign_in_via_ui`, `wait_for_selector`, `perform_enqueued_jobs_now`

### Сквозные system-тесты (созданы) — структура по секциям/сущностям
```
spec/system/
├── user/                       # 👤 USER SECTION (2.x)
│   ├── poi_map_spec.rb         # 2.2 POI Map (Poi) ✅
│   ├── user_lifecycle_spec.rb  # 2.3/2.5/3.2 User (эталон) ✅
│   ├── user_auth_spec.rb       # 2.5 Auth ✅
│   └── user_settings_spec.rb   # 2.4 User Settings ✅
├── admin/                      # 🛠 ADMIN SECTION (3.x)
│   ├── users_spec.rb           # 3.2 Admin Users ✅
│   ├── poi_category_spec.rb    # 3.3 PoiCategories ✅
│   └── pois_spec.rb            # 3.4 Admin Pois ✅
└── layer/                      # горизонтальные слои (4.x)
    └── gamification_spec.rb    # 4.2 Gamification ✅
```
- ✅ **`User`** (эталон, [`user_lifecycle_spec.rb`](spec/system/user/user_lifecycle_spec.rb:1)) — **ПРОШЁЛ (0 failures)**: регистрация → подтверждение → кошелёк → welcome-токены → админ live (статус/имя) → профиль (кошелёк/баланс) → мягкое удаление (deleted скрыт в All, виден через фильтр) → аудит → уведомления
- ✅ **`Admin::PoiCategory`** (эталон, [`poi_category_spec.rb`](spec/system/admin/poi_category_spec.rb:1)) — **ПРОШЁЛ (0 failures)**
- ✅ `Admin::User` ([`users_spec.rb`](spec/system/admin/users_spec.rb:1)) — смена статуса (браузер А → Б)
- ✅ `Auth` ([`user_auth_spec.rb`](spec/system/user/user_auth_spec.rb:1)) — регистрация → видимость у админа Б
- ✅ `Gamification` ([`gamification_spec.rb`](spec/system/layer/gamification_spec.rb:1)) — токены → баланс в профиле
- ✅ `User::Settings` ([`user_settings_spec.rb`](spec/system/user/user_settings_spec.rb:1))
- ✅ `Admin::Poi` ([`pois_spec.rb`](spec/system/admin/pois_spec.rb:1)) — создание POI → виден в списке админки
- ✅ `POI Map` ([`poi_map_spec.rb`](spec/system/user/poi_map_spec.rb:1)) — live-карта настроена (Selenium headful/headless + CDP-геолокация)

### Журнал последних прогонов
- ✅ **Полный suite** (06.08.2026) — **173 examples, 0 failures, 3 pending** (заглушки `PoiRating`×2 + `PoiComment` live). Тест-инфраструктура: переход с Cuprite на **Selenium Chrome** — headful-окно/вкладка локально (визуально наблюдать процесс) + headless (`--headless=new`) в CI (`CUPRITE_HEADLESS=true`/`ENV['CI']`); precompiled-ассеты для system-тестов (`RAILS_ENV=test bin/rails assets:precompile`); `wait_for_selector` → `has_css?(visible: false)` (скрытый `#poi-map-features`); `spec/requests` deprecation `:unprocessable_entity`→`:unprocessable_content`; rspec добавлен в `config/ci.rb`. Закрыты баги: (1) `Admin::PoisReflex#update` `morph "#poi-detail"` → Broadcaster (зона `#poi-detail` в `PoiBroadcaster`); (2) `Admin::DashboardService.stats` ключи `total_users/.../new_users_today`; (3) `Admin::DashboardBroadcaster` `morph`→`inner_html`; (4) POI не на карте — fallback-загрузка `map_component_controller.js`; (5) per-entry rescue аудит-зон (`PoiBroadcaster`/`Admin::UserBroadcaster`).
- ✅ **POI полное покрытие** (06.08.2026) — **unit+reflex+controller+broadcaster: 81 examples, 0 failures, 2 pending** (заглушки `PoiRating`/live-комментарии). Слои: `PoiService`/`Poi`/`PoiComment`/`PoiPolicy`/`PoiCommentPolicy`/`GamificationService`/`PoiBroadcaster`/`ToastBroadcaster`/`PoiReflex`/`Admin::PoisReflex`/`VersionObserverJob`/`PoisController`. **Полный suite: 153 examples, 1 failure** (🟡 `POI Map` — недонастроенная live-карта), **3 pending**. Выявлены и устранены баги: (1) SRID 4326 для geography-кастов + миграции `spatial_ref_sys`/`pois.description→jsonb`; (2) JSONB-поиск `search_pois`; (3) scope `nearby`; (4) `PoiPolicy::Scope` для гостя; (5) **награды TFT не начислялись** — `GamificationService.award!(:poi_create/:comment_create)` добавлены в `PoiService` (суммы из `config/gamification.yml`); (6) **бейджи first_poi/contributor не работали** — `User#pois` (has_many); (7) **live-комментарии отсутствовали** — `PoiCommentBroadcaster` + ветка `PoiComment` в `VersionObserverJob`; (8) `filter_by_categories` NameError (`bounds`→`params`); (9) **`PoiBroadcaster` использовал `morph`** — заменён на `inner_html`; (10) **`Poi::AddFormComponent` не существовал** — страница `new` убрана (модалка `Poi::FormComponent` остаётся основным UX), create→JSON 422, fetch-сабмит формы; (11) `PoisController` падал `PolicyScopingNotPerformedError` — `skip_after_action :verify_policy_scoped`.
- ✅ **Сущности User + PoiCategory** (05.08.2026) — **16 examples, 0 failures**: unit (`UserService`/`Admin::DashboardService`/`OsmImportService`/`UserInactivityJob`) + system (`user_lifecycle`/`poi_category`/`admin_users`/`auth`/`gamification`/`settings`)
- ✅ **Сущности User + PoiCategory** (05.08.2026) — **16 examples, 0 failures**: unit (`UserService`/`Admin::DashboardService`/`OsmImportService`/`UserInactivityJob`) + system (`user_lifecycle`/`poi_category`/`admin_users`/`auth`/`gamification`/`settings`)
- ✅ `poi_category_spec` (05.08.2026) — **1 example, 0 failures** (28.7 c) — после фикса OSM (убран `morph`-дубль карточки, инкрементальный `inner_html [data-poi-category-pois]`); закрывает баг 2.2 «вкладка POIs при OSM-импорте»
- ✅ `auth_spec` + `user_lifecycle_spec` (05.08.2026) — **2 examples, 0 failures** (46.5 c) — повторное подтверждение `User`/`Auth`; закрывает баг 2.5 «смена статусов / подтверждение email»
- ✅ Полный `bundle exec rspec` (06.08.2026) — **173 examples, 0 failures, 3 pending** (см. первую запись журнала)
- ✅ Deprecation Noticed 3.x сняты миграцией (`Noticed::Event`, `required_param`, без `deliver_by :database`) — см. 4.5

### Недоделано → чинить, затем тест
- ⚠️ `PoiComment` live для всех (сейчас только автор) — баг
- ⚠️ Загрузка фото (бинарники через Reflex) — баг

### Бэклог-связки
- 🔴 Конвейер broadcast реально доставляет (SolidQueue worker, cable-БД, подписка клиента)
- 🔴 `update_all` не используется для данных с аудитом (только `update!`/`save!`)
