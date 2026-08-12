# Travel Fi — Product Roadmap

> Единый план по **секциям приложения**: что работает, что в работе, что в планах.
> **Статусы:** `✅` работает · `🟡` частично · `🔴` хотелка/в планах · `⚠️` баг/долг
> Архитектура и инструкции — в [`README.md`](README.md:1) и `.roo/rules/` (здесь не дублировать).

---

## 0. Легенда

- **Секции = страницы приложения** (USER SECTION и ADMIN SECTION). Горизонтальные слои — сквозная инфраструктура.
- **В каждой секции** 3 блока: **Сделано** (`✅`), **Хотелки** (`🔴`), **Баги/Долги** (`⚠️`).
- **Маршруты:** профиль юзера — `/:slug`, админка — `/admin-panel` (см. [`config/routes.rb`](config/routes.rb:36)).
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
│   ├── 3.3 PoiCategories    (/admin-panel/poi_categories)  ✅
│   ├── 3.4 Pois             (/admin-panel/pois)     🟡
│   ├── 3.5 Settings         (/admin-panel/settings) ✅
│   └── 3.6 Contract Mgmt    🔴 (в планах)
├── 4. Горизонтальные слои
│   ├── 4.1 Auth & Roles     ✅
│   ├── 4.2 Gamification & Web3  🟡
│   ├── 4.3 Realtime-инфра   ✅
│   ├── 4.4 Audit            ✅
│   ├── 4.5 Notifications    ✅
│   ├── 4.6 i18n / UI        ✅
│   ├── 4.7 PWA / Devices    🟡
│   └── 4.8 CI / Tests / Production  🟡
└── 5. Связи + потоки данных
```

---

## 2. 👤 USER SECTION

### 2.1 Landing (главная)

**Маршрут:** `/` ([`PagesController#index`](app/controllers/pages_controller.rb:10))

**Цепочка:** PagesController → view (залогиненный редиректится на `/pois` через `session[:redirected_to_map]`)

**Компоненты:** [`Ui::NavbarComponent`](app/components/ui/navbar_component.rb:1) (общий layout [`app/views/layouts/application.html.erb`](app/views/layouts/application.html.erb:47))

**Статус:** 🔴 **Заглушка** — [`app/views/pages/index.html.erb`](app/views/pages/index.html.erb:1) содержит тестовый контент.

**Сделано:**
- ✅ Роут и контроллер страницы
- ✅ Редирект залогиненного на карту (однократно за сессию)

**Хотелки:**
- 🔴 Полноценный лендинг: hero + преимущества + CTA «Открыть карту»
- 🔴 Блок популярных категорий POI (из `PoiCategory.active`)
- 🔴 Статистика сообщества (POI, города, участники)
- 🔴 FAQ / Как это работает
- 🔴 Подвал (футер): ссылки, локали, PWA-установка

**Баги/Долги:**
- ⚠️ —

---

### 2.2 POI Map (карта + список + модалка)

**Маршруты:** `/pois` (index/new/create/update) — [`PoisController`](app/controllers/pois_controller.rb:12)

**Цепочка:** `PoisController` (index/просмотр) → [`PoiReflex`](app/reflexes/poi_reflex.rb:16) (load_pois_in_bounds, load_more_pois, filter_by_categories, apply_filters, reset_filters, show_detail, show_detail_modal, edit_poi, create_comment, reverse_geocode, set_location, show_geolocation_toast) → [`PoiService`](app/services/poi_service.rb:12) → PostGIS (`within_bounds`/`within_meters`) → [`PoiBroadcaster`](app/broadcasters/poi_broadcaster.rb:12) / `ToastBroadcaster` → `UserChannel` / `AdminChannel`

**Компоненты:** [`Poi::MapComponent`](app/components/poi/map_component.rb:1) (OpenLayers 10), `Poi::ListItemComponent`, `Poi::ShowComponent`, `Poi::FormComponent`, `Poi::FiltersComponent`, `Poi::CommentsComponent`, `Ui::SidebarComponent`. Модалки: `Poi::DetailsComponent`, `Poi::GalleryComponent`, `Poi::RatingsComponent` (заглушки).

**Статус:** 🟡 Частично

**Сделано:**
- ✅ Карта OpenLayers 10 + кластеризация + PostGIS-запросы по границам
- ✅ Сайдбар со списком видимых POI + «Load more» (пагинация по offset)
- ✅ Фильтры по категориям и поиск по JSONB name/description (Ransack + ILIKE)
- ✅ Карточка POI в модалке (шапка + табы)
- ✅ Форма создания/редактирования POI + мини-карта + обратный геокодинг (Nominatim)
- ✅ Галерея фото через `PhotoService` (ActiveStorage)
- ✅ Проксимити-проверка 100м для комментариев/редактирования (`check_proximity!`, `PoiCommentPolicy`)
- ✅ Live-комментарии: `PoiCommentBroadcaster` + ветка `PoiComment` в `VersionObserverJob` (автору); proximity-check 100м корректный (Boolean + SRID 4326, антифрод больше не «всегда проходит»)
- ✅ Награды TFT за создание POI/комментарий (`GamificationService.award!(:poi_create/:comment_create)`, суммы из `config/gamification.yml`)
- ✅ Live-карта: `poi:reload-features` → перезапрос с сервера; fallback-загрузка маркеров в `map_component_controller.js` (ретрай `_loadPoisInBounds`)
- ✅ OSM-импорт: вкладка POIs обновляется инкрементально (`inner_html [data-poi-category-pois]` каждые 10 импортов), без `morph`-дублей карточек
- ✅ Reverse geocoding при открытии формы редактирования (мини-карта в edit-режиме, автозаполнение address/city/country/zip)
- ✅ Валидация координат: `handleSubmit` блокирует отправку без lat/lng (i18n `missing_coords`)
- ✅ Мини-карта формы переинициализируется при `inner_html` (MutationObserver в `form_component_controller.js`)
- ✅ Создание/редактирование POI с карты — через модалку `Poi::FormComponent` на Reflex-флоу (`PoiReflex#create/#update` → `PoiService` → PaperTrail → `PoiBroadcaster`); без перезагрузки страницы, без JSON в ответе контроллера; тост пользователю через `ToastBroadcaster` (WebSocket); автозаполнение адреса отключено (`autocomplete="off"`)
- ✅ Динамические поля категории в форме POI: `PoiReflex#load_category_fields` рендерит `Poi::FormFieldsComponent` по field_type (string/text/number/boolean/select/multiselect) в обёртку `[data-poi-form-fields]` через CableReady (`inner_html`), неймспейс `poi[metadata][field_key]`
- ✅ Sidebar-оверлей: `Ui::SidebarComponent` раскрывается ПОВЕРХ карты (absolute), не выталкивая flex-поток — bounds карты не пересчитываются (`poi:reload-features` не дублируется, `_loadPoisInBounds` guard по `_lastBoundsKey`)

**Хотелки:**
- 🔴 `PoiRating` — 5-звёздная система + агрегация в `poi.rating`
- 🔴 Комментарии: live для всех + threaded-ответы
- 🔴 Галерея: сетка + lightbox/слайдер
- 🔴 OSRM: построение маршрута к POI + линия на карте
- 🔴 Offline-режим (PWA): тайлы + список (IndexedDB)

**Баги/Долги:**
- ⚠️ Загрузка фото (бинарники через StimulusReflex) → HTTP/multipart — отдельная задача
- ⚠️ Карточка POI: полировка UI (фокус-трап, aria, скролл-блокировка) - отдельная задача
- ✅ Автозаполнение адреса браузером отключено: `autocomplete="off"` на address/city/country/zip_code в `Poi::FormComponent` и админ-`EditComponent`
- ⚠️ Админка. Форма редактирования: компоновка + `Ui::DropdownComponent` вместо `<select>`; мини-карта не инициализируется; `rating` — консолидируемое вычисляемое поле, НЕ редактируется вручную. Пользователь покажет структуру страницы — отдельная задача.
- ⚠️ Фильтры. Компонент. Разобраться. - отдельная задача.
---

### 2.3 User Profile (профиль пользователя)

**Маршрут:** `/:slug` (show/edit) — [`UsersController`](app/controllers/users_controller.rb:13)

**Цепочка:** `UsersController` (show/edit, рендер) + [`UserReflex`](app/reflexes/user_reflex.rb:10) (update_profile) → [`UserService`](app/services/user_service.rb:15) (name + avatar через `PhotoService`) → [`UserBroadcaster`](app/broadcasters/user_broadcaster.rb:12) → `user_<id>` (inner_html по обёртке `[data-user-profile-id]`)

**Компоненты:** [`Users::ProfileComponent`](app/components/users/profile_component.rb:11), [`Users::FormComponent`](app/components/users/form_component.rb:1), `Users::RewardsComponent`, табы `Ui::TabsComponent`.

**Статус:** 🟡 Частично

**Сделано:**
- ✅ Отображение профиля (аватар, имя, email, статус, баланс TFT, бейджи, роли); кошелёк юзеру НЕ показывается (только админ — вкладка Wallet)
- ✅ История начислений TFT в профиле: `Users::RewardsComponent` (live `inner_html [data-user-rewards]` через `TokenTransactionBroadcaster`)
- ✅ Редактирование имени + аватар (через Broadcaster)
- ✅ Настройки уведомлений на `/:slug/settings` (см. 2.4)
- ✅ Pundit: свой профиль или админ
- ✅ `User#badges` — бейджи по `badge_ids` через `gamification.yml` (профиль не падает)
- ✅ Live-обновление имени через `UserBroadcaster`: рендер из job фиксирует `I18n.with_locale(default)`, `cable_controller.js` применяет CableReady-операции по одной (per-op try/catch)
- ✅ Автоматика `inactive`: `UserInactivityJob` (active без активности 6+ мес → inactive) + `UserService.mark_inactive_old_users` + запись в `config/recurring.yml`

**Хотелки:**
- 🔴 Live-переключение табов (активность/аудит) без перезагрузки
- 🔴 Секция уровней/бейджей геймификации
- 🔴 Личная статистика активности (POI, комментарии, токены)
- 🔴 Поле ввода промо/скидочного кода в профиле при покупке платных фич (Token Spend / premium): применить код со скидкой перед подтверждением оплаты

**Баги/Долги:**
- ⚠️ Табы (активность/аудит) в профиле — переключение не live
- ⚠️ Неподтверждённая верификация → определить поведение (сброс/флаг/повтор)

---

### 2.4 User Settings (настройки пользователя)

**Маршрут:** `/:slug/settings` — [`Users::SettingsController#show`](app/controllers/users/settings_controller.rb:10)

**Цепочка:** `SettingsReflex#update` ([`app/reflexes/settings_reflex.rb`](app/reflexes/settings_reflex.rb:5)) → [`SettingService.update`](app/services/setting_service.rb:3) → [`SettingBroadcaster`](app/broadcasters/setting_broadcaster.rb:11) → `user_<id>` (toast)

**Компоненты:** [`Settings::FieldComponent`](app/components/settings/field_component.rb:1) (в т.ч. админ-набор через `admin/settings`)

**Статус:** ✅ Сделано

**Сделано:**
- ✅ Переключатели событий (in-app / email / push) для пользователя
- ✅ Автосохранение через Reflex + toast (тосты только через broadcast, без локальных рендеров)

**Хотелки:**
- 🔴 Верификация email/push перед включением каналов
- 🔴 Группировка и поиск по событиям

**Баги/Долги:**
- ⚠️ —

---

### 2.5 Auth pages (аутентификация)

**Маршруты:** Devise `/users/*` (sessions/registrations/confirmations/passwords/unlocks) + Google OAuth (`/users/auth/google_oauth2`) — [`config/routes.rb`](config/routes.rb:19)

**Цепочка:** Devise-контроллеры (`users/*`) → `UserService.handle_google_oauth` ([`app/services/user_service.rb`](app/services/user_service.rb:34)) → `Setting.create_for_user` + `WalletService.create_hidden_wallet` (OAuth сразу) + welcome-токены (`award_registration_bonus!`)

**Статус:** ✅ Сделано

**Сделано:**
- ✅ Регистрация/логин/подтверждение/восстановление пароля (Devise + confirmable + lockable)
- ✅ **Регистрация НЕ авторизует до подтверждения:** редирект на страницу входа с flash «подтвердите почту» (`after_inactive_sign_up_path_for` → `new_user_session_path`, `signed_up_but_unconfirmed`)
- ✅ Google OAuth (OmniAuth) + аватар через `PhotoService`
- ✅ Роли по умолчанию (:user), реферальный код при регистрации
- ✅ **Скрытый custodial-кошелёк создаётся СРАЗУ при регистрации** (и email, и OAuth): welcome-начисления сразу получают on-chain адрес → relay отправляет мгновенно
- ✅ Welcome-токены TFT (10) при регистрации + реферальные бонусы (15/5) через `award_registration_bonus!` — **мгновенно, без лок-периода** (off-chain леджер)
- ✅ Реферальная связь `users.referred_by_id` (self-join) + журнал транзакций `TokenTransaction` — при регистрации с рефкодом начисляется обоим (15/5), реферер/рефералы видны в админке
- ✅ Смена статусов / подтверждение email / soft-delete — подтверждено `user_lifecycle_spec` (0 failures)

**Хотелки:**
- 🔴 EIP-2771: sponsored-транзакции (on-chain отправка через сервер уже есть, см. 4.2)
- 🔴 Регистрация через OAuth-контроллер с реферальным кодом: в OAuth-флоу отсутствует UI ввода/передачи рефкода (`?ref=` на кнопке authorize / поле). Бэкенд-приём кода работает — `User.from_google_oauth(auth, referral_code_input)` + `UserService.handle_google_oauth` (см. §4.2), требуется только UI-часть.

**Баги/Долги:**
- ⚠️ —

---

## 3. 🛠 ADMIN SECTION (`/admin-panel`)

> Layout [`app/views/layouts/admin.html.erb`](app/views/layouts/admin.html.erb:43): Navbar + Sidebar + контент + тосты. Канал: `AdminChannel` (admin/moderator). База: [`Admin::BaseController`](app/controllers/admin/base_controller.rb:11).

### 3.1 Dashboard (дашбоард)

**Маршрут:** `/admin-panel` — [`Admin::DashboardController#index`](app/controllers/admin/dashboard_controller.rb:9)

**Цепочка:** `Admin::DashboardReflex` (refresh/refresh_stats) + `Admin::DashboardService.stats` → [`Admin::DashboardBroadcaster`](app/broadcasters/admin/dashboard_broadcaster.rb:3) (`inner_html [data-admin-*]`) → `AdminChannel`

**Компоненты:** [`Admin::DashboardComponent`](app/components/admin/dashboard_component.rb:15), `Admin::Dashboard::StatCardComponent`, `Ui::BreadcrumbsComponent`

**Статус:** ✅ Сделано

**Сделано:**
- ✅ Карточки статистики (total/active/suspended/pending + new_users_today) с live-обновлением
- ✅ `Admin::DashboardService.stats` возвращает `total_users/active_users/suspended_users/new_users_today` (совпадает с `DashboardComponent`); `new_users_today` = зарегистрированные сегодня (не pending)
- ✅ Последние пользователи + последние активности (из `versions`)
- ✅ Авторизация: admin/moderator

**Хотелки:**
- 🔴 Чарты: Chartkick/Groupdate (активность, гео, категории, просмотры)
- 🔴 GA/GTM-интеграция
- 🔴 KPI по POI (pending/approved/rejected), импортам OSM, комментариям

**Баги/Долги:**
- ⚠️ admin_channel.js: skip morph (selector not found): `[data-admin-stats-total-users]` — селектор шлётся, когда админ на другой странице (безвредное предупреждение, стоит глушить)

---

### 3.2 Users (пользователи)

**Маршруты:** `/admin-panel/users` (index/show/update) — [`Admin::UsersController`](app/controllers/admin/users_controller.rb:12)

**Цепочка:** [`Admin::UsersReflex`](app/reflexes/admin/users_reflex.rb:11) (update/destroy/filter/sort/reset_filters) → [`Admin::UserService`](app/services/admin/user_service.rb:19) → [`Admin::UserBroadcaster`](app/broadcasters/admin/user_broadcaster.rb:15) (inner_html таблицы `[data-admin-users-list]`, prepend, remove, audit, dispatch_event) → `AdminChannel`

**Компоненты:** `Admin::Users::TableComponent`, `Admin::Users::RowComponent`, `Admin::Users::User::ShowComponent`, `EditComponent`, `ActivityComponent`, `WalletComponent`, `AuditLogComponent` (`Ui::AuditEntryComponent`), `Ui::FiltersComponent`, `Ui::TabsComponent`

**Статус:** ✅ Сделано (CRUD + live)

**Сделано:**
- ✅ Список + поиск + фильтр по статусу (включая deleted) + сортировка + пагинация (pagy)
- ✅ Детальная страница: профиль + табы (Activity / Wallet / Audit Log)
- ✅ Вкладка Wallet: баланс TFT + история транзакций (`TokenTransaction`) + explorer-ссылка (выжимка 4+4) + реферальная инфо (реферер/кол-во рефералов); live `inner_html [data-admin-user-wallet]`
- ✅ Редактирование (name/email/status/role) + мягкое удаление (статус `deleted`, запись не удаляется)
- ✅ Live: prepend нового юзера + обновление таблицы (inner_html) через `AdminChannel`; deleted скрыт в «All», виден через фильтр статуса
- ✅ Управление ролями: форма шлёт `role_id` (одна роль), permit `role_id` ↔ `Admin::UserService#update_user_roles!`
- ✅ Аватар Google OAuth: `Ui::AvatarComponent#avatar_url` с fallback на blob-URL + rescue (сбой representation в worker)

**Хотелки:**
- 🔴 Массовые операции (батч-статус, батч-роль)
- 🔴 Экспорт списка (CSV)

**Баги/Долги:**
- ⚠️ —

---

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
- ✅ **Live карта:** событие `poi:reload-features` → `_loadPoisInBounds()` (перезапрос с сервера)
- ✅ **Уведомления по настройкам:** единая `PoiCategoryNotification` (мультикаст инициатор + админы), персональные Setting-фильтры (in-app/email/push); колонки `osm_import_*` в `settings`

**Хотелки:**
- 🔴 DAO-верификация категорий
- 🔴 Импорт OSM в фоне через SolidQueue (сейчас синхронно в Reflex)

**Баги/Долги:**
- ⚠️ Вкладка «Аудит лог»: admin_channel.js не находит селектор `[data-audit-log]` (skip morph) — проверить рендер зоны аудита

---

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
- ✅ `Admin::PoisReflex#update`/`change_status` — `morph :nothing` + тост; зона `#poi-detail` рендерится `PoiBroadcaster` (live у ВСЕХ админов)
- ✅ Мини-карта при редактировании: `form_component_controller.js` инициализирует карту через MutationObserver (порядок CableReady-операций не «зависает»)
- ✅ Бейджи `first_poi`/`contributor` (связь `User#pois`)
- ✅ После создания POI через админку точка появляется на карте (`poi:reload-features` + fallback-загрузка маркеров)

**Хотелки:**
- 🔴 Карточка POI по единому паттерну: табы Details/Comments/Ratings/Gallery/Audit
- 🔴 Массовая модерация

**Баги/Долги:**
- ⚠️ Галерея: просмотр `Poi#photos` (сетка + lightbox) не реализован

---

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

**Баги/Долги:**
- ⚠️ —

---

### 3.6 Contract Mgmt (управление контрактами)

**Статус:** 🔴 В планах (см. слой 4.2)

**Хотелки:**
- 🔴 Mint/rate/pause/награды через админку
- 🔴 `ContractSnapshot` (мониторинг контрактов): модель `contract_type`/`data jsonb`/`created_at` с ротацией (в коде мониторинга пока нет)

**Баги/Долги:**
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
- ✅ **ТОКЕННАЯ МОДЕЛЬ:** награды — токены TFT (`UserReward`, off-chain леджер), `User#token_balance`; `GamificationService` (`award!`, `award_referral!`, `badge_key`, `check_badges!`); бейджи — `gamifications` (event_type badge); welcome 10 / referral 5+5 TFT (реферер — vesting, новичок — мгновенно). **Уровни — плановая метрика от `token_balance`** (см. хотелку ниже).
- ✅ **Журнал транзакций `TokenTransaction`:** каждая награда → запись credit (amount/action_key/tx_hash/status/chain_id/wallet_id/user_reward_id) в единой транзакции с `UserReward`; `tx_hash` заполняется после on-chain отправки, в админке — explorer-ссылка с выжимкой 4+4; баланс остаётся мгновенным (off-chain, без лок-периода)
- ✅ **On-chain relay (серверная отправка):** `TokenTransactionService.relay!` + `TokenTransactionRelayJob` (SolidQueue) — подпись EIP-155 (RLP/ECDSA в [`Crypto::Ethereum`](lib/crypto/ethereum.rb:1)) приватным ключом оператора (`OPERATOR_PRIVATE_KEY`, `.env`) → `eth_sendRawTransaction` → `transfer(address,uint256)` на **reward pool-контракт** (`REWARDS_CONTRACT_ADDRESS`) — токены берутся из баланса pool (НЕ mint), газ спонсирует оператор (gasless для юзера). **`relay!` устойчив к любым исключениям (в т.ч. `Exception` — WebMock в тестах): помечает `failed`, job не роняет worker.**
- ✅ **Сериализация relay по оператору:** `limits_concurrency key: "token-relay-operator", to: 1, on_conflict: :block` — все начисления подписываются одним ключом, отправка строго последовательна (не конфликтуют nonce при параллельном relay).
- ✅ **Авто-ретрай упавших relay:** `TokenTransactionRetryJob` (recurring каждые 15 мин) находит `status: failed` + `tx_hash: nil` и переотправляет через `relay!` только мгновенные/доступные по лок-периоду (vesting, ещё не разблокированные, — ждут claim).
- ✅ **Точка начисления = статус active:** welcome-токены и реферальные бонусы начисляются ТОЛЬКО активному аккаунту. Email — после подтверждения (`ConfirmationsController#show`, кошелёк создан до начисления); OAuth — сразу (юзер активен). Реферальная связь (`referred_by`) фиксируется при регистрации (`UserService.save_referral!`) — переживает подтверждение.
- ⚠️ **OAuth-рефкод:** бэкенд принимает рефкод — `User.from_google_oauth(auth, referral_code_input)` пробрасывает `?ref=`/`session[:referral_code]` в `UserService.handle_google_oauth` (реф-начисления работают при переданном коде). Но в OAuth-флоу НЕТ UI ввода рефкода и кнопка authorize не формирует `?ref=` → полноценный реферальный сценарий через OAuth недоступен до реализации UI-части (см. хотелку §2.4).
- ✅ **Конфиг pool + мониторинг:** секция `pool` в `config/gamification.yml` (`lock_days`, `warning_balance`, `critical_balance`); `ContractBalanceCheckJob` (SolidQueue recurring) читает баланс pool через `TokenTransactionService.balance_of` и шлёт админам `ContractBalanceNotification` (Noticed) при низком балансе (жёлтая/красная плашка в интерфейсе — позже, с компонентами).
- ✅ **ECDSA-подпись на Ruby 3.4:** [`Crypto::Ethereum#ecdsa_sign`](lib/crypto/ethereum.rb:231) — координаты точки извлекаются через `to_octet_string(:uncompressed)` (у API `OpenSSL::PKey::EC::Point` нет `#x/#y`); `sign_transaction` покрыт тестом
- ✅ **Проверка в dev (Base Sepolia):** запустить `bin/jobs` → зарегистрировать юзера → relay-job отправит mint → в explorer транзакция, в админке explorer-ссылка (выжимка 4+4); `balanceOf(custodial)` == off-chain `token_balance`. RSpec RPC **мокает** (WebMock) — реальная сеть в тестах не затрагивается
- ✅ **Custodial-кошелёк:** модель `Wallet` (`kind: custodial/external`), `WalletService.create_hidden_wallet` (EIP-55, шифрование private key `MessageEncryptor`), генерация на Ruby без новых гемов ([`Crypto::Ethereum`](lib/crypto/ethereum.rb:1) — OpenSSL secp256k1 + keccak256 + EIP-55). Email — после подтверждения, OAuth — сразу.
- ✅ Контракты ERC-20 TFT (`travel-fi.sol`) — **написаны, задеплоены и верифицированы в тестнете** (детали сети — в `.env`); on-chain отправка через `TokenTransactionService.relay!` ([`token_transaction_service.rb`](app/services/token_transaction_service.rb:22))
- 🔴 EIP-2771 forwarder + admin hot-wallet; Jetton TON + bridge
- 🔴 Token Spend (premium-фичи), Contract Mgmt в админке
- 🔴 **Уровни от `token_balance`**: сколько TFT накопил юзер → уровень (репутация/прогрессия в профиле); пороги — продукт-задача
- ⚠️ **Курс ETH/USDT и TON/USDT:** разработать в сервисе транзакций метод получения актуального курса и вызывать перед каждой конвертацией. Токен фиксированный (1 TFT = 1 USDT) — курс нужен для понимания реальной рыночной ситуации и установки курса обмена.
- ✅ **Лок-блокировка начислений (антифрод реферера):** `referral_bonus_referrer` исключён из `INSTANT_ACTION_KEYS` — реферер идёт по vesting-лок-периоду (`updated_at + lock_days`), маркер получения — булево `claimed`. Бонус новичку и welcome — мгновенно (lock=0).
- 🔴 **Целевая on-chain схема начислений (двухэтапная off-chain → on-chain, блокировка в БД):**
  - **Этап 1 (off-chain, сразу, через Сервис→Джоб):** действие → `UserReward` + `TokenTransaction` в единой транзакции. Баланс/бейджи/уровни обновляются сразу — заблокированные TFT виртуальные (внутренний счёт в БД), on-chain `relay` уходит в очередь только в момент разблокировки/claim.
  - **Этап 2 (on-chain, по кнопке «Забрать награды» или авто-claim job):** одна relay-отправка через Сервис→Джоб (SolidQueue) → реальные TFT на custodial-кошелёк. Газ платим один раз за claim.
  - **Лок-период — вычислимая проверка, поля НЕТ:** запись `TokenTransaction` разблокирована, если `updated_at + lock_days(config)` уже наступило. Маркер «получено» — **булево поле** (`claimed`), проставляется при успешном relay; при этом `updated_at` обновляется (срабатывает аудит PaperTrail → broadcast).
  -   **Регистрация/бонус новичку:** relay **сразу** (lock=0) — на кошелёк, без локдейса. **Реферальный бонус РЕФЕРЕРА** — по лок-периоду (vesting, антифрод фейковых регистраций).
  - **`sendRewardBatch` — ТОЛЬКО под акции/массовые награды** (несколько юзеров одной tx), не как регулярный процесс.
  - **Плашка «доступно Y к снятию / Z на балансе»:** расчёт на бэке из скоупов `TokenTransaction` — `available` (разблокированы по `updated_at` И `claimed == false`), `locked` (ещё не прошёл лок-период). Ручной счётчик не нужен.
  - **Claim-флоу:** кнопка → Сервис (`UserService.claim_rewards!`) → собирает `available`-начисления → ставит relay-Джоб → при успехе `claimed = true` (и `updated_at` обновляется → аудит → broadcast).
- 🔴 **Вынести все динамические настройки геймификации из `config/gamification.yml` в сущность `Setting` + UI в админке `/admin-panel/settings`:** не только pool (`rewards_lock_days`, `pool_warning_balance`, `pool_critical_balance`), но и rewards-суммы (registration 10, referral 15+5, poi_create/photo/comment/vote) и thresholds бейджей (first_poi, contributor, explorer, recruiter, veteran, …). `GamificationService` читает из `Setting` (фолбэк на YAML-дефолты до первого сохранения); форма (числовые инпуты/пороги) через конвейер `SettingsReflex#update` → `SettingService.update` → `SettingBroadcaster`; аудит PaperTrail; синхронизация lock on-chain через `setLockDays`. **Пока настройки остаются в YAML — полный перенос позже отдельной задачей.**
- 🔴 **Награда TFT за достижение уровня (рейтинг-система):** при переходе через порог `token_balance` (уровень из конфига) → разовый reward по двухэтапной схеме §4.2 (новый `action_key`, напр. `level_up`). Реализуется вместе с рейтинг-системой.
- 🔴 **Акции / массовые награды через `sendRewardBatch`:** разовые кампании награждения группы юзеров одной tx (акции, розыгрыши, бонусы комьюнити). Отдельная фича поверх двухэтапной схемы.

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
- ✅ **Noticed 3.0.0:** `ApplicationNotification < Noticed::Event`, `required_param`, без `deliver_by :database` (записи сохраняются автоматически), `WebPush < Noticed::DeliveryMethod`. `action_cable` (UserChannel) настроен.
- ✅ Email-доставка проверена: `UserMailer.profile_updated` с `params[:recipient]`; Setting-фильтр `email_enabled?` — покрыт тестом `spec/notifications/user_profile_notification_spec.rb`

### 4.6 i18n / UI (ViewComponents)
**Статус:** ✅ Сделано
- ✅ 4 локали (en/ru/es/zh); sidecar ViewComponents (rb + html + css + controller.js + 4 yml)
- ✅ Только зелёно-голубая палитра Tailwind (emerald/teal/sky), иконки MDI, запрет partials
- ✅ UI-библиотека: `Ui::CardComponent`, `BtnComponent`, `DropdownComponent`, `TabsComponent`, `BadgeComponent`, `AvatarComponent`, `TooltipComponent`, `BreadcrumbsComponent`, `PaginationComponent`, `ConfirmDialogComponent`, `ToastComponent`, `SidebarComponent`, `NavbarComponent`, `FiltersComponent`, `AuditEntryComponent`, `ClipboardComponent`, `DateComponent`, `HamburgerComponent`

### 4.7 PWA / Devices
**Статус:** 🟡 Частично
- ✅ Манифест + service worker ([`app/views/pwa/`](app/views/pwa/manifest.json.erb:1))
- 🟡 Иконки установки приложения (логотип/фон) — есть, требуется доработка
- 🔴 Offline: тайлы карты, offline-список (IndexedDB), offline GPX/CSV, push

### 4.8 CI / Tests / Production
**Статус:** 🟡
- ✅ CI: brakeman/bundler-audit/rubocop/yarn audit — есть; **rspec в [`config/ci.rb`](config/ci.rb:1) добавлен**
- ✅ **Полный RSpec suite зелёный:** `CUPRITE_HEADLESS=true bundle exec rspec` → **250 examples, 0 failures, 3 pending** (заглушки: PoiRating, live-комментарии для всех). Прогон ~2.5 мин
- ✅ **Стабильность прогона:** потоковая индикация `[START] <example>` с `$stdout.flush` в [`spec/rails_helper.rb`](spec/rails_helper.rb:38) — виден текущий пример при затыке; ENV-моки с `and_call_original` — каскадный сбой `DatabaseCleaner` (грязная БД → ложные падения `User scopes`/`DashboardService.stats`) устранён
- 🔴 Production-деплой: [`config/deploy.yml`](config/deploy.yml:1) — заглушки `192.168.0.1`/`localhost:5555`; домен, SMTP, force_ssl
- 🟡 Performance: tile caching, PostGIS-оптимизация, SolidCable clustering, GeoJSON-кэш

---

## 5. Связи сущностей + потоки данных

### 5.1 Связи сущностей (таблица)

| # | Модель | Связь | Модель | Описание |
|---|--------|-------|--------|----------|
| 1 | `User` | 1 — 1 | `Setting` | у каждого юзера одна строка настроек уведомлений |
| 2 | `User` | 1 — N | `Gamification` | бейджи юзера (event_type badge) |
| 3 | `User` | M — N | `Role` | роли через таблицу `users_roles` (Rolify) |
| 4 | `User` | 1 — N | `Poi` | юзер — создатель точек |
| 5 | `User` | 1 — N | `PoiComment` | юзер — автор комментариев |
| 6 | `User` | 1 — N | `Wallet` | custodial (наш) / external (свой) кошелёки |
| 7 | `User` | 1 — N | `UserReward` | off-chain начисления токенов TFT |
| 8 | `User` | 1 — N | `TokenTransaction` | журнал движения токенов (credit/debit) |
| 9 | `User` | 1 — 1 | `User` (referred_by) | self-join: кто пригласил (рефкод) |
| 10 | `PoiCategory` | 1 — N | `PoiCategoryField` | категория определяет набор динамических полей |
| 11 | `PoiCategory` | 1 — N | `Poi` | категория содержит точки |
| 12 | `Poi` | 1 — N | `PoiComment` | комментарии к точке (self-join `parent_id` — ответы) |
| 13 | `Poi` | 1 — N | `Photo` | галерея фото (ActiveStorage) |
| 14 | `Poi` | 1 — N | `PoiRating` | 5-звёздные оценки (🔴 в планах) |
| 15 | *(все)* | — | `PaperTrail::Version` | аудит изменений всех моделей с `has_paper_trail` |

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

- **User Profile ↔ Admin Users:** изменение юзера → PaperTrail → `VersionObserverJob#handle_user_update` → `Admin::UserBroadcaster` (AdminChannel) + `UserBroadcaster` (user_N) + `UserProfileNotification` (Noticed, фильтр по `Setting`).
- **POI Map ↔ Admin Pois:** создание/изменение POI → `VersionObserverJob#handle_poi_update` → `PoiBroadcaster` (список + тост + `poi:reload-features` → карта) + `Admin::DashboardBroadcaster.broadcast_stats_update`.
- **PoiCategories ↔ POI Map:** изменение категории/полей → `PoiCategoryBroadcaster` (AdminChannel, карточка/поля/POI/аудит); видимость POI на карте зависит от `poi_categories.active` (scope `Poi.visible`).
- **OSM-импорт ↔ POI Map:** `Admin::PoiCategoriesReflex#import_from_osm` → `OsmImportBroadcaster` (прогресс/результат в user_N) + `poi:reload-features` → перезагрузка маркеров карты.
- **Settings ↔ Notifications:** `SettingsReflex` → `SettingService` → `SettingBroadcaster` (user_N); `Setting`-фильтры применяются при рассылке Noticed.
- **Gamification ↔ Wallet/TokenTransaction:** `GamificationService.award!` → `UserReward` + `TokenTransaction` (в одной транзакции) → `TokenTransactionRelayJob` (SolidQueue) → on-chain mint.

---

## 6. 🧪 ТЕСТЫ

### Принцип (эталон)
Один тест на сценарий = **«браузер А → браузер Б»**: А выполняет действие (Reflex/Service → save! → PaperTrail → VersionObserverJob → Broadcaster → CableReady) → Б видит live-обновление БЕЗ перезагрузки + уведомления по своим настройкам.

### Инфраструктура
- ✅ RSpec + FactoryBot + PostGIS; **Capybara + Selenium Chrome**: headful-окно локально, headless (`--headless=new`) в CI (`CUPRITE_HEADLESS=true`/`ENV['CI']`)
- ✅ DatabaseCleaner (system — truncation, остальные — transaction); WebMock (мок Overpass/RPC); ActiveJob `:test`
- ✅ ActionCable в тестах — `solid_cable` (live между браузерами), тестовая cable-БД `travel_fi_test_cable`
- ✅ Хелперы [`spec/support/system_helpers.rb`](spec/support/system_helpers.rb:1): `browser_a`/`browser_b`, `sign_in_via_ui`, `wait_for_selector`, `perform_enqueued_jobs_now`
- ✅ Потоковая индикация `[START] <example>` в [`spec/rails_helper.rb`](spec/rails_helper.rb:38) — видно текущий пример при затыке

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
    ├── gamification_spec.rb    # 4.2 Gamification ✅
    └── referral_rewards_spec.rb# 4.2 Реферальные начисления ✅
```
- ✅ **`User`** (эталон, [`user_lifecycle_spec.rb`](spec/system/user/user_lifecycle_spec.rb:1)) — регистрация → подтверждение → кошелёк → welcome-токены → админ live (статус/имя) → профиль (баланс/кошелёк скрыт) → мягкое удаление → аудит → уведомления
- ✅ **`Admin::PoiCategory`** (эталон, [`poi_category_spec.rb`](spec/system/admin/poi_category_spec.rb:1))
- ✅ `Admin::User` ([`users_spec.rb`](spec/system/admin/users_spec.rb:1)) — смена статуса (браузер А → Б)
- ✅ `Auth` ([`user_auth_spec.rb`](spec/system/user/user_auth_spec.rb:1)) — регистрация → видимость у админа Б
- ✅ `Gamification` ([`gamification_spec.rb`](spec/system/layer/gamification_spec.rb:1)) — токены → баланс + история в профиле
- ✅ `Referral rewards` ([`referral_rewards_spec.rb`](spec/system/layer/referral_rewards_spec.rb:1)) — регистрация по рефкоду → начисления обоим (15/5), баланс+история, Wallet у админа (explorer-ссылка 4+4)
- ✅ `TokenTransactionService` ([`token_transaction_service_spec.rb`](spec/services/token_transaction_service_spec.rb:1)) — relay mint (WebMock RPC) + `to_wei`; `TokenTransactionRelayJob` ([`token_transaction_relay_job_spec.rb`](spec/jobs/token_transaction_relay_job_spec.rb:1)); подпись/RLP — [`ethereum_spec.rb`](spec/lib/crypto/ethereum_spec.rb:39)
- ✅ `User::Settings` ([`user_settings_spec.rb`](spec/system/user/user_settings_spec.rb:1))
- ✅ `Admin::Poi` ([`pois_spec.rb`](spec/system/admin/pois_spec.rb:1)) — создание POI → виден в списке админки
- ✅ `POI Map` ([`poi_map_spec.rb`](spec/system/user/poi_map_spec.rb:1)) — live-карта (Selenium headful/headless + CDP-геолокация)

### Журнал последних прогонов
- ✅ **Полный suite (07.08.2026)** — **250 examples, 0 failures, 3 pending** (заглушки `PoiRating`×2 + `PoiComment` live). Закрытые баги: (1) `relay!` ронял job — `WebMock::NetConnectNotAllowedError < Exception` не ловился `rescue StandardError`, добавлен перехват `Exception` + `mark_failed`; (2) ECDSA-подпись падала на Ruby 3.4 — координаты `OpenSSL::PKey::EC::Point` через `to_octet_string(:uncompressed)`; (3) ENV-моки ломали `DatabaseCleaner` (каскад: грязная БД → ложные падения `User scopes`/`DashboardService.stats`) — добавлен `and_call_original`; (4) устранён warning `already initialized constant` (дублирование констант `TOKEN_ADDRESS`/`RPC_URL`).
- ✅ **Полный suite (06.08.2026)** — **173 examples, 0 failures, 3 pending**. Тест-инфраструктура: Selenium Chrome (headful/headless), precompiled-ассеты, `wait_for_selector` → `has_css?(visible: false)`, rspec в `config/ci.rb`. Закрыты баги: `Admin::PoisReflex#update` morph→Broadcaster; `Admin::DashboardService.stats` ключи; `Admin::DashboardBroadcaster` morph→inner_html; POI не на карте — fallback-загрузка; per-entry rescue аудит-зон.
- ✅ **POI полное покрытие (06.08.2026)** — **unit+reflex+controller+broadcaster: 81 examples, 0 failures, 2 pending**. Закрытые баги: SRID 4326; JSONB-поиск; `nearby`; `PoiPolicy::Scope` для гостя; награды TFT; бейджи `first_poi`/`contributor`; live-комментарии; `filter_by_categories` NameError; `PoiBroadcaster` morph→inner_html; `Poi::AddFormComponent`; `PolicyScopingNotPerformedError`.
- ✅ **Сущности User + PoiCategory (05.08.2026)** — **16 examples, 0 failures**: unit (`UserService`/`Admin::DashboardService`/`OsmImportService`/`UserInactivityJob`) + system (`user_lifecycle`/`poi_category`/`admin_users`/`auth`/`gamification`/`settings`)
- ✅ `poi_category_spec` (05.08.2026) — **1 example, 0 failures** — после фикса OSM-импорта (инкрементальный `inner_html [data-poi-category-pois]`)
- ✅ `auth_spec` + `user_lifecycle_spec` (05.08.2026) — **2 examples, 0 failures** — повторное подтверждение `User`/`Auth`
- ✅ Deprecation Noticed 3.x сняты миграцией (`Noticed::Event`, `required_param`, без `deliver_by :database`)

### Недоделано → чинить, затем тест
- ⚠️ `PoiComment` live для всех (сейчас только автор) — баг
- ⚠️ Загрузка фото (бинарники через Reflex) — баг

### Бэклог-связки
- 🔴 Конвейер broadcast реально доставляет (SolidQueue worker, cable-БД, подписка клиента)
- 🔴 `update_all` не используется для данных с аудитом (только `update!`/`save!`)
