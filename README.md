# Travel Fi — Architecture & System Design

Travel Fi — Rails 8.1 приложение для туристических услуг с DeFi-функциональностью и ERC-20 токеном (TFT). Архитектура — WebSocket-first: асинхронные обновления через ActionCable (SolidCable), фоновые задачи через SolidQueue, кэш-инфраструктура SolidCache (кэширование в коде временно отключено), аудит через PaperTrail.

> Демо: https://noneternally-approbative-rosanne.ngrok-free.dev/ (запуск сервераа по согласованию)

## 🏗️ Technology Stack

| Слой | Компоненты |
|------|-----------|
| **Backend Framework** | Rails 8.1 |
| **Database** | PostgreSQL + PostGIS |
| **Authentication** | Devise + Bcrypt |
| **Authorization** | Pundit + Rolify |
| **Audit & Versioning** | Paper Trail |
| **Frontend** | Stimulus, StimulusReflex |
| **Map Engine** | OpenLayers 10 (кластеризация, Overlay, PostGIS-запросы) |
| **Realtime** | ActionCable, SolidCable, CableReady |
| **Background Jobs** | SolidQueue |
| **Job Dashboard** | SolidQueueDashboard |
| **Caching** | SolidCache (инфраструктура; кэш в коде отключён) |
| **Search & Filtering** | Ransack |
| **Gamification** | Собственная система (баллы/бейджи/уровни) |
| **Notifications** | Noticed (database + email + action_cable + web_push) |
| **CSS Framework** | Tailwind CSS, Stimulus-Components |
| **Web3** | viem |

---

## 🎯 Project Vision

**Миссия:** Community-driven карта для путешественников — глобальная платформа для шеринга POI (Points of Interest), критичных во время путешествия.

**Целевая аудитория:** Budget backpackers, Digital nomads, Solo-туристы из развивающихся стран, Vanlife путешественники.

**Ключевое преимущество:** Нет одного сильного глобального игрока в большинстве ниш (WiFi-точки заняты WiFi Map/Instabridge, остальное — белые пятна).

## 📍 POI Categories (от самого востребованного)

1. **Места покупки prepaid SIM и eSIM-киосков** — нет специализированного приложения; фильтр по тарифам, 24/7, близость к аэропорту.
2. **Общественные туалеты + душевые** — конкуренты (Flush, SitOrSquat) узкие; инновация: комбо + фото + рейтинг чистоты + доступность.
3. **Бесплатные точки набора воды (refill + фонтаны)** — конкуренты слабые; вирусный трекер «сколько пластика сэкономил».
4. **Общественные души и прачечные** — Park4Night/iOverlander имеют как побочку; расписание, цена, доступ для гостей отелей.
5. **Хранение багажа (luggage storage)** — платные сети (Radical Storage/Bounce); community-вариант (кафе/хостелы) — бесплатный.
6. **Зарядки и розетки** — фильтр по типу (медленная/быстрая), наличие WiFi, рабочие розетки.
7. **Банкоматы с минимальной комиссией + обменники** — ATM Fee Saver не на живой карте; user-reported курсы.
8. **Бесплатная парковка / overnight spots** — расширение на все виды транспорта.
9. **Круглосуточные аптеки + пункты первой помощи** — критично в Азии/ЛатАм/Африке; наличие лекарств, языки.
10. **Бонусные лайфхаки** — зарядки в коворкингах, pet-friendly, LGBTQ+-safe, пункты бесплатной еды.

## 💰 Web3 Integration Point

**Монетизация через ERC-20 (TFT):**
- Юзеры получают токены за добавление/верификацию POI
- Premium-функции за токены (фильтры, аналитика, рейтинги)
- DAO для управления категориями и политиками
- Affiliate для провайдеров (хостелы, отели, сервисы)

### 🔐 Web3 & Onboarding (Custodial / Embedded Wallet)
- **Автоматическое создание кошелька:** при успешной регистрации/подтверждении сервис генерирует скрытый (custodial) кошелёк **на Ruby** — `OpenSSL::PKey::EC` (secp256k1) + собственная реализация keccak256 + EIP-55 (модуль [`Crypto::Ethereum`](lib/crypto/ethereum.rb:1), без новых гемов). Приватный ключ шифруется `ActiveSupport::MessageEncryptor` (`WalletService`).
- **`viem` — только фронтенд** (npm, [`package.json`](package.json:23)): EIP-2771 sponsored-транзакции, Contract Mgmt, чтение баланса ERC-20. Генерация ключей на сервере к viem отношения не имеет.
- **Zero-Friction UX:** пользователь не взаимодействует с Web3-интерфейсом на старте — начисление/списание токенов бесшовно.
- **DeFi-интеграция:** на кошелёк зачисляются токены (off-chain леджер `UserReward`) за активность → доступ к премиум-функциям. On-chain отправка — через [`ContractService`](app/services/contract_service.rb:22) (контракты задеплоены, см. `.env`).

---

## ⚙️ Единый поток данных (Database-Triggered Workflow)

> **Эталон архитектуры.** Любое изменение состояния проходит по этой цепочке. Reflex/Controller НЕ рендерит DOM после сохранения — UI обновляет ТОЛЬКО Broadcaster через `VersionObserverJob`. Соблюдение цепочки гарантирует live-обновление у всех подписанных браузеров (инициатор и остальные).

### Фаза 1 — ВВОД (браузер)
1. **Stimulus-контроллер** (sidecar компонента) перехватывает событие (клик/ввод)
2. `this.stimulate("XxxReflex#action", params)` — RPC через WebSocket
3. **Reflex**: `current_user` → `morph :nothing` (отмена полного перерендера) → `deep_symbolize_keys(params)` → `authorize_with_pundit!(record, :action?)`
4. Reflex **только делегирует** в Service. Логики в рефлексе — НОЛЬ.

### Фаза 2 — СОСТОЯНИЕ (PostgreSQL)
5. **Service**: вся бизнес-логика + `Model.save!`/`update!` **внутри транзакции**
6. **PaperTrail** создаёт `Version` (event, `whodunnit` = current_user.id, `object_changes`)
7. `after_commit :broadcast_changes` → `VersionObserverJob.perform_later(version.id)`

### Фаза 3 — АСИНХРОННОЕ РАСПРОСТРАНЕНИЕ (SolidQueue)
8. **VersionObserverJob**: парсит `item_type` → ветка `handle_<model>_update` → вызывает `XxxBroadcaster.call`
9. **Broadcaster**: рендерит зоны (ViewComponent через `helpers.render`) → `cable_ready["AdminChannel"].inner_html(selector:, html:)` по селекторам-обёрткам
10. `.broadcast` → ActionCable (**SolidCable**) → стрим

### Фаза 4 — ДОСТАВКА (браузеры А и Б)
11. Клиент подписан на канал (`AdminChannel`/`user_N`) → `received` применяет операции **по одной** (`forEach` + `try/catch`, пропуск отсутствующих селекторов)
12. DOM обновляется **точечно** (inner_html по обёрткам) — без перезагрузки

### Строгие правила слоёв
| Слой | Делает | Запрещено |
|------|--------|-----------|
| Controller | Только доступ (Pundit) + рендер страницы + данные вкладок + pagy | Логика |
| Reflex | Мост UI→Service: `morph :nothing` + authorize + делегирование | Рендерить DOM после сохранения |
| Service | Бизнес-логика, `save!`/`update!` в транзакции | — |
| Model | Только данные | Логика рассылок |
| Broadcaster | Рендер зон + `inner_html` + broadcast | `morph`, `update_all` |
| VersionObserverJob | Маршрутизация по `item_type` | — |
| ViewComponent | Только презентация (sidecar 7 файлов, 4 локали) | partials, хардкод текста |

### Практические правила интеграции (обязательны)
- **Зарезервированные ключи StimulusReflex** (`id`, `params`, `selectors`, `morph`, `attrs`, `flash`, `event`, `permanent_attribute_name`) нельзя передавать top-level в `this.stimulate` — объект станет опциями, `args` придёт пустым. Используй неймспейсные ключи (`field_id`) или `{ params: {...} }`; из FormData удаляй `id`.
- **Reflex не рендерит DOM после сохранения** — только `morph :nothing` + Service. Селекторный морф — только для чтения (пагинация/фильтры).
- **Broadcaster использует `inner_html`, не `morph`** — `morph` падает на `undefined.dispatchEvent` (`parent.children[idx]`).
- **Контейнер-цель отдельно от содержимого:** селектор `[data-...]` — на обёртке в шаблоне страницы, НЕ на корне компонента (иначе вложенность при `inner_html`).
- **Нормализация параметров:** в Reflex `deep_symbolize_keys(params)` перед Service (строковые ключи из JS).
- **Аудит и массовые обновления:** `update!`/`save!` (версии → Broadcast); `update_all` запрещён для данных с аудитом (в т.ч. реордер позиций).
- **Клиентская обработка CableReady:** в `received` операции по одной (`forEach` + `try/catch`), пропуск отсутствующих селекторов.
- **Рендер вложенных ViewComponent в Broadcaster (SolidQueue worker):** только `<%= render %>`/`helpers.render` (view_context). Запрещён вложенный `ApplicationController.render` — падает в job, зона молча не отправляется. Per-entry `rescue` (см. `AuditLogComponent#render_entries_html`).
- **Broadcast из worker (`bin/jobs`):** инициализировать ActionCable PubSub до `SolidQueue::Cli.start` — `ActionCable.server.config.cable = { "adapter" => "solid_cable" }` (СТРОКОВЫЙ ключ; символьный `:adapter` → дефолт `"redis"` → `Redis::CannotConnectError`), затем `ActionCable.server.pubsub`.
- **`pagy()` в Broadcaster:** в worker нет `request` → `NameError: request`. Добавь mock: `def request; @request ||= ActionDispatch::Request.new({}); end`.
- **Чекбоксы (Rails `check_box`):** hidden(value=0)+checkbox с одним `name`. В JS выбирай `input[name='...'][type='checkbox']`, иначе всегда читается hidden (false).

### Сценарий «А создал, Б видит»
- **А:** Фазы 1–2 + синхронный `redirect_to` (только А) + тост инициатору (`dispatch_event`)
- **Б:** Фазы 3–4: job → broadcaster → `AdminChannel` → все подписанные админы получают `inner_html` без перезагрузки

---

## 📡 Каналы и доставка (ActionCable Channels)

Всё отправляется через WebSocket — нет данных в JSON-ответе контроллера.

**Личный канал:** каждый пользователь подписан на `user_<id>` (`UserChannel`).
- `user_100` / `user_200` / `user_N` — персональные обновления и уведомления (включая админов как обычных пользователей).

**Админ-канал:** `AdminChannel` — подписка для ролей `admin` И `moderator` (moderator имеет права на edit в политиках).
- Live-обновления админки (поля категорий, лента аудита, статистика) шлются в `AdminChannel` (см. «Единый паттерн админ-сущности»).

**ActionCable** — WebSocket-инфраструктура Rails: долгоживущее соединение, сервер шлёт сообщения всем подписанным на канал браузерам.

**SolidCable** — database-backed адаптер ActionCable: сообщения в PostgreSQL вместо Redis; позволяет масштабировать несколько Rails-процессов без отдельной инфраструктуры (процесс 1 отправил → процесс 2 доставил браузеру).

---

## 🗂 Единый паттерн админ-сущности (для быстрого расширения админки)

Одна админ-сущность (User, Poi, Setting, PoiCategory…) реализуется по единому шаблону:

### 1. Компоненты (Sidecar, полный набор: rb + html.erb + css + controller.js + 4 yml)
- **Index**: `Admin/<entity>/TableComponent` + `RowComponent`.
- **Show**: `Admin/<entity>/<entity>/ShowComponent` + для КАЖДОГО таба отдельный компонент (`FieldsListComponent`, `PoisListComponent`, `AuditLogComponent`, `ActivityComponent`).
- **Edit**: `Admin/<entity>/<entity>/EditComponent`.
- Контейнер-цель (`[data-...]`) — на обёртке в `show.html.erb`, корень компонента без неё.

### 2. Reflex (`app/reflexes/admin/<entity>_reflex.rb`)
- `create` / `update` / `destroy` — `morph :nothing` → `deep_symbolize_keys(params)` → `authorize_with_pundit!` → Service → `send_success`/`send_error` (dispatch_event в `user_#{id}`).
- `filter` / `<entity>_page` (пагинация) — чтение, рендер через `ApplicationController.render(Component)` + `inner_html` + `broadcast`.

### 3. Service (`app/services/<entity>_service.rb`)
- `create` / `update` / `destroy` — `Model.save!` в транзакции; `update!`, НЕ `update_all` (аудит).
- `audit_versions(entity:)` — версии сущности + связанных (для удалённых — через `object`), безопасный `parse_version_object`.

### 4. Broadcaster (`app/broadcasters/<entity>_broadcaster.rb`)
- `include CableReady::Broadcaster`, `include Pagy::Method` (+ mock `request` для pagy).
- `broadcast` — рендер зон по одной (`inner_html` по селектору-обёртке), каждая зона в `rescue`.
- Вложенные ViewComponent из job — только через `<%= render %>`/`helpers.render`.
- Результат: `cable_ready["AdminChannel"]` → `.broadcast`.

### 5. Канал
`AdminChannel` (`app/channels/admin_channel.rb`) — подписка `admin` ИЛИ `moderator`.

### 6. VersionObserverJob (`app/jobs/version_observer_job.rb`)
- Для каждого `item_type` — ветка `handle_<model>_update(version)` → `XxxBroadcaster.call(<entity>: version.item || version.reify)`.

### 7. Живой аудит (лента)
- Единый `Ui::AuditEntryComponent` для всех сущностей: `changes` фильтрует «пусто→пусто», читаемый JSONB, `field_key_from_version` fallback на `version.object`.
- Панель таба аудита — компонент с собственным Stimulus-контроллером на корне (контроллер-предок для пагинации), `goToPage` → Reflex `<entity>_page`.

### 8. Формы (чекбоксы!)
Rails `check_box` генерирует пару инпутов с одним `name` (hidden `value="0"` + checkbox). В JS выбирай `input[name='...'][type='checkbox']`, иначе читается hidden (false). Пример: `form.querySelector("[name='poi_category_field[required]'][type='checkbox']")`.

---

## 🏛 Архитектурные решения

Зафиксированные решения. При изменении любого пункта — обновлять этот раздел и инструкции (`.roo/rules`).

| Решение | Обоснование |
|---------|-------------|
| Database-Triggered Workflow | PaperTrail → VersionObserverJob → Broadcaster → CableReady. БД = Single Source of Truth |
| StimulusReflex + CableReady | WebSocket-first, без JSON API. Reflex не рендерит DOM после сохранения |
| Sidecar ViewComponents | Изоляция шаблонов/стилей/JS, 4 локали, запрет partials |
| PostGIS | Пространственные запросы (bounds, radius, ST_DWithin) |
| Proximity Check (100м) | Антифрод для комментариев и голосования через `ST_DWithin` |
| ERC-20 (TFT) геймификация | Utility-токен: награды за активность, верификация, premium |
| EIP-2771 (ERC-2771) | Спонсированные транзакции — газ платит платформа |
| TON Cross-chain Bridge | Lock ERC-20 → Mint Jetton для Telegram экосистемы |
| SolidQueue вместо Sidekiq | Zero Redis (SolidQueue/SolidCache/SolidCable) |
| PWA + Telegram Mini App | Вместо нативных приложений — охват, бюджет, гранты TON Foundation |

### Токеномика TFT (полузакрытая система)
- **Лимит эмиссии:** 1 000 000 TFT (18 decimals), задано в [`travel-fi.sol`](travel-fi.sol) (`MAX_SUPPLY`).
- **Токены НЕ сжигаются (no burn).** TFT циркулируют внутри платформы: начисляются за активность (POI, фото, комментарии, рефералы), расходуются на premium-услуги и верификацию, возвращаются в оборот. Дефицит — за счёт жёсткого лимита эмиссии.
- **Utility-механики:** награды, репутация/уровни, премиум-фильтры, приоритетная верификация, DAO-голосование.
- **Продажа (crowdsale) — отдельная юридически выверенная сущность**, не входит в грант-заявку (регуляторный риск).

### Открытые технические долги
- [ ] **`ContractService.detect_changes_for_contract`** использует `Rails.cache` (TTL 2h) как снапшот — эфемерно. Заменить на модель `ContractSnapshot` (contract_type, data jsonb, created_at) с ротацией.
- [ ] **Точечное кэширование** — SolidCache включён, кэш в коде отключён. Возвращать точечно: ShowComponent `[category, I18n.locale]`, агрегаты с зависимостью от коллекции; НЕ кэшировать формы.
- [ ] **`Ui::ConfirmDialogComponent`** — вынести модалку в отдельный компонент, убрать окно из `Poi::ShowComponent`/`Poi::FormComponent`.

---

## 📐 Архитектура системы

### Принцип «Одна сущность»
- **Model** — данные и связи (только база).
- **Service** — единственная точка входа для бизнес-логики.
- **Reflex** — точка входа UI-взаимодействий через WebSocket.
- **Controller** — только доступ (Pundit), рендеринг, Pundit-политики.
- **Broadcaster** — слой доставки обновлений интерфейса (CableReady).
- **Notification** — уведомления (Noticed) с фильтрацией через `Setting`.

### DATABASE as Single Source of Truth
Данные в PostgreSQL с историей через PaperTrail: транзакционность (всё или ничего), аудит каждого изменения, надёжность (не прошла транзакция — ничего не отправлено).

---

## 📦 Стандарты разработки

### ViewComponent (Sidecar Subdirectory)
Полное описание — в [`.roo/rules/01-INSTRUCTIONS.md`](.roo/rules/01-INSTRUCTIONS.md) и [`.roo/rules/03-COMPONENT-REFERENCE.md`](.roo/rules/03-COMPONENT-REFERENCE.md). Кратко:
- Каждый компонент — класс `XxxComponent < ApplicationComponent` (НЕ module-обёртки, НЕ `ViewComponent::Base`).
- Sidecar-папка с одноимённым именем: `html.erb` + `css` + `controller.js` + 4 yml (en/ru/es/zh) — **полный набор, всегда** (даже пустые JS/CSS).
- Корневой тег шаблона: `data-controller="kebab-case-name"`.
- Partial'ы запрещены. Инлайн `<script>`/`<style>` запрещены.

### Стиль и цвета
- Только зелено-голубая гамма Tailwind (`emerald`, `teal`, `sky`). Кастомные стили запрещены.
- Иконки — только MDI, с комментарием названия класса (`<%# Иконка: mdi-pencil %>`).

### Интернационализация
- 4 локали: en, ru, es, zh. Хардкод текста запрещён.
- Переводы — в sidecar YAML компонента, относительные ключи `t(".key")`. Ключи в `config/locales/*.yml` для текстов внутри ViewComponent — запрещено.

### Комментарии
Каждый метод документируется комментарием СТРОГО перед объявлением.

---

## 🔌 Основные компоненты фронтенда

### Stimulus
Лёгкий фреймворк взаимодействия браузера с Rails. Слушает события (клики, ввод), отправляет сигналы на Rails, обновляет DOM, управляет состоянием. Жизненный цикл: инициализация при появлении элемента в DOM, очистка при удалении.

### StimulusReflex
Реактивные компоненты через WebSocket: браузер отправляет действие, сервер обновляет нужные части DOM (морфинг). Используй `this.stimulate("Reflex#method", params)`. **`prevent_refresh!` НЕ СУЩЕСТВУЕТ** — вместо него `morph :nothing`.

### CableReady
Генератор команд обновления DOM. Транспортный слой: команда (обновить/заменить/добавить/удалить/уведомление) отправляется через WebSocket и выполняется браузером.

---

## 📨 Уведомления и фоновые задачи

### Noticed
Мультиканальная система уведомлений: одно уведомление — несколько каналов (Email, SMS/Twilio, Push/WebPush, In-app/WebSocket).

### SolidQueue
Database-backed очередь (вместо Sidekiq + Redis). Долгие операции сохраняются в БД, worker-процессы выполняют асинхронно.

### SolidCache
Database-backed кэш (альтернатива Redis). Инфраструктура настроена, **кэширование в коде отключено** (исключить stale при broadcast-морфах). Когда вернуть (точечно): статичные части ShowComponent — ключ `[category, I18n.locale]`; агрегаты — с зависимостью от коллекции (`[category, category.pois, I18n.locale]`); НЕ кэшировать формы. Конфигурация: `config/cache.yml` (256MB), `:solid_cache_store` в production, `bin/rails dev:cache` в dev.

### SolidQueueDashboard
Веб-интерфейс мониторинга очередей, статусов задач, повторного запуска упавших.

### ReverseGeocodingService
Обратное геокодирование (страна/город/адрес по координатам). API: Nominatim (бесплатно, 1 запрос/сек). Файл: [`app/services/reverse_geocoding_service.rb`](app/services/reverse_geocoding_service.rb).

### AI-сервисы (платные LLM API)
Единый `AiService` (OpenAI-совместимые API: OpenAI, DeepSeek; переключение через ENV). Сценарии: `check_toxicity`, `translate_missing_keys`, AI-рекомендации (Premium). Реализация — TODO.

### Ransack
Поиск и фильтрация данных на основе параметров запроса, без ручного SQL.

---

## 🏆 Геймификация и токены TFT

**ТОКЕННАЯ МОДЕЛЬ:** награды начисляются токенами TFT (не «баллами»).

**Архитектура:** модель `UserReward` (`amount` TFT, `action_key`, `wallet_id`) — off-chain леджер начислений; `User#token_balance` = сумма начислений; сервис `GamificationService` (`award!`, `award_referral!`, `badge_key`, `check_badges!`); бейджи — модель `Gamification` (event_type `badge`, репутационные достижения); конфиг [`config/gamification.yml`](config/gamification.yml) (rewards — токены TFT, badges — достижения).

**Награды (TFT):** регистрация (welcome) 10, реферал (реферер) 15, реферал (новый) 5, добавление POI 20, фото POI 5, комментарий 5, голос за POI 2.

**Бейджи:** `registration_complete`, `first_poi`, `contributor` (10+), `explorer` (5+ городов), `recruiter` (5+ рефералов), `veteran` (баланс 1000+ TFT).

**I18n:** названия бейджей и наград локализованы (en, ru, es, zh).

---

## 🗄️ Данные и аудит

### Paper Trail
Полное версионирование моделей: ЧТО изменилось (старые/новые значения), КТО (пользователь), КОГДА, ЧТО произошло (create/update/destroy). Триггер всех последующих действий (notifications, broadcasts).

### PostgreSQL + PostGIS
Основная БД + географическое расширение: координаты как географические типы, пространственные запросы (объекты в радиусе, на маршруте).

---

## 🔐 Безопасность

### Devise
Аутентификация: регистрация, вход, восстановление пароля, сессии. Пароли — bcrypt (необратимое хеширование). Предоставляет `current_user`, защиту маршрутов от неавторизованного доступа.
