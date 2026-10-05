# Travel Fi — Продуктовый ROADMAP

> Живой статус продукта по **секциям приложения**: что работает, что в работе, что в планах.
> **Статусы:** `✅` работает · `🟡` частично · `🔴` в планах · `⚠️` баг/долг
> **Грант-оценка (что строить + сроки + стоимость)** — в [`docs/MILESTONES_ru.md`](MILESTONES_ru.md). **Реестр долгов** — в [`docs/TECH-DEBTS_ru.md`](TECH-DEBTS_ru.md). **Инструкции для ИИ-агента** — в `.roo/rules/*`. Архитектура — в [`docs/README_ru.md`](README_ru.md).

---

## 1. Карта секций приложения

```
Travel Fi
├── 👤 USER SECTION          (/:locale/)
│   ├── 2.1 Landing          (/)               🔴
│   ├── 2.2 POI Map          (/pois)           🟡
│   ├── 2.3 User Profile     (/:slug)          🟡
│   ├── 2.4 User Settings    (/:slug/settings) ✅
│   └── 2.5 Auth pages       (/users/*)        ✅
├── 🛠 ADMIN SECTION         (/:locale/admin-panel)
│   ├── 3.1 Dashboard        (/admin-panel)          ✅
│   ├── 3.2 Users            (/admin-panel/users)    ✅
│   ├── 3.3 PoiCategories    (/admin-panel/poi_categories)  ✅
│   ├── 3.4 Pois             (/admin-panel/pois)     🟡
│   ├── 3.5 Voting           (/admin-panel)          ✅
│   ├── 3.6 Settings         (/admin-panel/settings) ✅
│   ├── 3.7 Comments         (/admin-panel/comments) ✅
│   └── 3.8 Contracts        🔴 (в планах)
├── 4. Горизонтальные слои
│   ├── 4.1 Auth & Roles     ✅
│   ├── 4.2 Gamification & Web3  🟡
│   ├── 4.3 Realtime-инфра   ✅
│   ├── 4.4 Audit            ✅
│   ├── 4.5 Notifications    🟡
│   ├── 4.6 i18n / UI        ✅
│   ├── 4.7 PWA / Devices    🟡
│   └── 4.8 CI / Tests / Production  🟡
└── 5. Связи + потоки данных
```

---

## 2. 👤 USER SECTION

### 2.1 Landing (главная)
**Статус:** 🔴 заглушка — [`app/views/pages/index.html.erb`](app/views/pages/index.html.erb:1) содержит тестовый контент. Роут и редирект залогиненного на карту работают.
**Хотелки:** полноценный лендинг (hero, популярные категории, статистика сообщества, FAQ, футер).

### 2.2 POI Map (карта + список + модалка)
**Статус:** 🟡 частично — ядро работает (OpenLayers 10 + кластеризация, PostGIS-фильтры, модалка POI с табами, галерея фото, threaded-комментарии live, OSM-импорт включая `.pbf`, динамические поля категорий, награды TFT, live-карта).
**В планах / долги (детали → [`docs/MILESTONES_ru.md`](MILESTONES_ru.md) M1/M3):** Suggested Edits + консенсус 100м, Quick Toggles, «Сообщить об ошибке», live-табы, OSRM-маршрут, PWA-офлайн. `PoiComment` live для всех (сейчас только автор). Фильтры. Компонент. Разобраться.

### 2.3 User Profile (профиль пользователя)
**Статус:** 🟡 частично — отображение профиля, история начислений TFT, блок TFT Balance (доступно/заблокировано + claim), правка имени/аватара, Pundit, автоматика `inactive`.
**В планах / долги:** live-переключение табов (активность/аудит); поведение неподтверждённой верификации; секция уровней/бейджей геймификации (по вкладу).

### 2.4 User Settings (настройки пользователя)
**Статус:** ✅ сделано

### 2.5 Auth pages (аутентификация)
**Статус:** ✅ сделано — Devise + confirmable + lockable, Google OAuth (+рефкод на бэке), скрытый custodial-кошелёк при регистрации, welcome/реферальные TFT.

---

## 3. 🛠 ADMIN SECTION (`/admin-panel`)

### 3.1 Dashboard
**Статус:** ✅ сделано — карточки статистики, последние юзеры/активности (из `versions`), авторизация admin/moderator.
**В планах:** графики (Chartkick/Groupdate).

### 3.2 Users
**Статус:** ✅ сделано — список/поиск/фильтр/сортировка/пагинация, табы детали, вкладка Wallet, правка + мягкое удаление, live-обновления.
**В планах:** массовые операции (батч-статус, батч-роль).

### 3.3 PoiCategories + поля + OSM-импорт
**Статус:** ✅ сделано — CRUD категорий, CRUD полей в edit-форме, авто-slug, OSM-маппинг + импорт (Overpass + локальный `.pbf`), иконки-маркеры категорий, единый аудит.
**В планах:** DAO-верификация категорий.

### 3.4 Pois (точки интереса)
**Статус:** 🟡 частично — список/поиск/фильтр/пагинация, детали (Details/Map/Audit), модерация статуса (вкл. `imported`), обратный геокодинг в форме, бейджи, live-карта.
**В планах:** карточка POI по единому паттерну (табы).

### 3.5 Голосования / Community Moderation
**Статус:** ✅ ядро сделано — полиморфный `Vote` (POI/фото/комментарии), бейджи «одобрено/отклонено сообществом» по порогу, `ReputationService`, антифрод 100м.
**В планах:** Suggested Edits (→ M1), авто-скрытие фото при отклонении сообществом (→ M1), привязка репутации к уровням (по вкладу, → M1).

### 3.6 Settings (настройки уведомлений админа)
**Статус:** ✅ сделано — значимые переключатели событий, геймификация в `Setting.gamification_config` + форма правки в админке, автосохранение + тост + аудит.
**В планах:** разделение уведомлений админских событий по ролям (Rolify).

### 3.7 Comments (админ-модерация)
**Статус:** ✅ сделано — список/фильтр/пагинация, детали с аудитом, скрыть/показать/удалить (staff-only), гейтинг по статусу юзера, live-обновление комментария.
**В планах:** Lookbook-превью для `Admin::Comments::*`, A/B-спеки для live-комментариев.

### 3.8 Contracts (Contract Mgmt)
**Статус:** 🔴 в планах — админ-раздел управления **ВСЕМИ ТРЕМЯ контрактами** (TravelFiToken / TravelFiRewards / TravelFiCrowdsale). Сервисный слой (`ContractService`) есть; UI отсутствует. → [`docs/MILESTONES_ru.md`](MILESTONES_ru.md) M2.

---

## 4. Горизонтальные слои

### 4.1 Auth & Roles
**Статус:** ✅ — Devise (email + confirmable + lockable), Google OAuth, Pundit-политики, Rolify (`admin`/`moderator`/`user`), модель статусов (`pending→active→inactive`, `suspended`/`banned`/`deleted`) с `suspended_until` + авто-разблокировка, классификатор `UserAccessService`.

### 4.2 Gamification & Web3
**Статус:** 🟡 — токен-модель работает (off-chain `UserReward` + журнал `TokenTransaction`, on-chain relay, claim); 6 бейджей. **Decimals:** токен = 18, jetton в TON = 9 (мост маппит 9↔18, без переделки контрактов).
**В планах:** уровни/бейджи по вкладу юзера (→ M1), on-chain `balanceOf` как источник правды TFT-баланса (→ M1), два кошелька (custodial/external; external = MetaMask/hot-wallet; WalletConnect — на будущее) + EIP-2771 (→ M2), Token Spend (→ M2), Contract Mgmt UI (→ M2), распределённое хранение ключей / Vault (поиск бесплатного сервиса, → M2).

### 4.3 Realtime-инфраструктура
**Статус:** ✅ — StimulusReflex + CableReady + SolidCable, каналы `UserChannel`/`AdminChannel`, SolidQueue + SolidQueueDashboard, SolidCache (инфраструктура).

### 4.4 Audit (PaperTrail)
**Статус:** ✅ — PaperTrail (Single Source of Truth) → `VersionObserverJob` → broadcasters; правило `update!`/`save!`, `update_all` запрещён для данных с аудитом.

### 4.5 Notifications (Noticed)
**Статус:** 🟡 — in-app/database ✅, email — долг. Noticed 3.0.0, фильтрация каналов через `Setting`, Web push.

### 4.6 i18n / UI (ViewComponents)
**Статус:** ✅ — 4 локали (en/ru/es/zh), sidecar ViewComponents, зелёно-голубая палитра Tailwind, иконки MDI, UI-библиотека, ленивые Stimulus-контроллеры.
**Долг:** строки админ-сайдбара захардкожены (вынести в i18n-ключи).

### 4.7 PWA / Devices
**Статус:** 🟡 — манифест + service worker (App Shell, статический кеш, офлайн-фолбэк), иконки установки. **Офлайн-данные** (IndexedDB, тайлы) — в планах (→ M3).

### 4.8 CI / Tests / Production
**Статус:** 🟡 — CI (brakeman/bundler-audit/rubocop/yarn audit/rspec) есть; полный RSpec suite зелёный; **продакшен-деплой — ПОСЛЕДНИЙ шаг** (→ M3).

---

## 5. Связи + потоки данных

- **Эталонная цепочка (Database-Triggered Workflow):** Controller/Reflex → Service (Pundit + `save!` в транзакции) → PostgreSQL + PaperTrail → `VersionObserverJob` → Broadcaster (`inner_html`) → CableReady → ActionCable (SolidCable) → DOM. Полное описание — [`docs/README_ru.md`](README_ru.md).
- **Каналы:** `UserChannel` → `user_<id>` (личный) + `pois_map` (общий карты); `AdminChannel` → `admin_<id>` (личный) + `admin_feed` (общий админки).
- **Граф сущностей:** см. [`docs/README_ru.md`](README_ru.md) (таблицы и потоки) — здесь не дублируется.

> Версионирование: ROADMAP — живой статус; историю изменений смотреть через `git log`. Решения — в разделе README «Архитектурные решения».
