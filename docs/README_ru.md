# Travel Fi — Архитектура и системный дизайн

Travel Fi — **открытая комьюнити-платформа гуманитарной безопасности и общественной инфраструктуры**: карта мест, важных для повседневной жизни и безопасности, — питьевая вода, общественные туалеты и душевые, бесплатные зарядки, безопасные ночёвки, аптеки и пункты первой помощи. Проект — **и для путешественников, и для жителей городов**, одновременно выступая как инфраструктура помощи для беженцев, перемещённых лиц и семей с детьми. Вход в Web3 — **без барьеров**: custodial-кошелёк создаётся незаметно при регистрации, токены (TFT) начисляются за вклад, а продвинутые пользователи могут подключить свой кошелёк. Позиционирование — **Digital Public Goods (DPG)**: открытая инфраструктура на пользу обществу.

Архитектура — Rails 8.1, WebSocket-first: асинхронные обновления через ActionCable (SolidCable), фоновые задачи через SolidQueue, кэш-инфраструктура SolidCache (**кэширование в коде временно отключено**), аудит через PaperTrail.

> Демо: https://noneternally-approbative-rosanne.ngrok-free.dev/ (admin@example.com/12345678, запуск сервера по согласованию)

> Промо-демо - https://drive.google.com/file/d/1-WECv_pAtkrJqNUK_LF9o1pbySfmNgFx/view?usp=drive_link

> Youtube - https://youtu.be/R1NnzuvNBAU

> Github Repo - https://github.com/omni395/travel_fi

> Поддержать Travel Fi на Giveth: https://giveth.io/project/travel-fi
> Поддержать Travel Fi на Artizen: https://artizen.fund/index/p/travel-fi
> Поддержать Travel Fi на Karmahq: https://www.karmahq.org/project/travel-fi

> **Набор документов:** статус продукта по секциям → [`docs/ROADMAP_ru.md`](docs/ROADMAP_ru.md); грант-оценка (что делать + время + стоимость) → [`docs/MILESTONES_ru.md`](docs/MILESTONES_ru.md); реестр долгов → [`docs/TECH-DEBTS_ru.md`](docs/TECH-DEBTS_ru.md); инструкции для ИИ-агента — `.roo/rules/*`. Английское зеркало — `README.md`.

---

## 🏗️ Технологический стек

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
| **Job Dashboard** | SolidQueueDashboard - https://github.com/akodkod/solid-queue-dashboard |
| **Caching** | SolidCache (инфраструктура; **кэширование временно отключено** в коде) |
| **Search & Filtering** | Ransack |
| **Gamification** | Собственная система: токены TFT + бейджи; уровни — от вклада пользователя (не `token_balance`) |
| **Notifications** | Noticed (database + email + action_cable + web_push) |
| **CSS Framework** | Tailwind CSS, Stimulus-Components |
| **Web3** | viem (фронтенд), 3 EVM-контракта |

---

## Project Vision & Current State

**Миссия:** Комьюнити-карта для путешественников и местных жителей — глобальная платформа для обмена критически важными точками (POI) во время поездок и в повседневной жизни.

**Target audience:** Бюджетные бэкпекеры, цифровые кочевники, соло-путешественники из развивающихся стран, ванлайферы, а также жители городов и различных местностей, которые пользуются услугами и общественными благами.

**Ключевое преимущество:** Нет единого сильного мирового игрока в большинстве ниш (Wi-Fi точки заняты WiFi Map/Instabridge, всё остальное — белые пятна).

**Позиционирование (Digital Public Goods):** Travel Fi — открытая комьюнити-карта мест, важных для повседневной жизни и безопасности: точки питьевой воды, общественные туалеты и душевые, бесплатные зарядки, безопасные ночёвки, аптеки и пункты первой помощи, хранение багажа. Проект — **и для путешественников, и для жителей городов**, одновременно выступая как гуманитарная и общественная инфраструктура: беженцы, перемещённые лица и семьи с детьми могут найти воду, помощь и связанные с проживанием услуги — а каждый может добавлять и проверять такие точки.
> Web3 здесь **без барьеров**: custodial-кошелёк создаётся незаметно при регистрации, а токены (TFT) начисляются за вклад. Разбираться в криптовалютах не нужно — просто контрибьють, а «крипто-часть» остаётся под капотом; продвинутые пользователи могут подключить свой кошелёк. Позиционирование — **Digital Public Goods**: открытая инфраструктура на пользу обществу.

**Текущая стадия:** Прототип в фазе активной разработки. Базовая архитектура готова и доказала техническую жизнеспособность. Продукт еще не запущен, сейчас идет доработка кода, отладка логики и подготовка архитектуры к Production.

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

## 💰 Web3 и смарт-контракты

**Три EVM-контракта** (написаны, задеплоены и верифицированы в тестнете; все — 18 decimals):
- [`TravelFiToken.sol`](contracts/TravelFiToken.sol:13) — **Эмитент**: жёсткая эмиссия `MAX_SUPPLY = 1 000 000 000`, разовое распределение, затем пауза.
- [`TravelFiCrowdsale.sol`](contracts/TravelFiCrowdsale.sol) — **Кассир**: покупка/продажа токенов за ETH/USDT (комиссия при продаже — анти-арбитраж), оплата фич (Token Spend).
- [`TravelFiRewards.sol`](contracts/TravelFiRewards.sol) — **Награды**: выдача с vesting (`lockDays`).

**Gasless (EIP-2771):** бэкенд (`Crypto::Ethereum`) выступает как Relayer — подписывает и транслирует, не перекладывая оплату газа на кошельки пользователей.

**Decimals:** EVM-контракты = 18; будущий TON Jetton = 9 (стандарт). Мост маппит 9↔18 через коэффициент конверсии — существующие контракты НЕ переписываются.

### 🚀 Future Roadmap: Telegram & TON
- **Telegram Mini App** — вход в экосистему прямо из мессенджера (карта POI, уведомления, TFT) без установки отдельного приложения. **TON Cross-chain Bridge** — TFT свободно перемещаются между EVM и TON (lock ERC-20 → mint Jetton), делая токен по-настоящему кросс-чейн.
- *Стратегический вектор развития, реализуется после Production-запуска и набора первичной базы.* → [`docs/MILESTONES_ru.md`](docs/MILESTONES_ru.md) M4.

**Монетизация через ERC-20 (TFT):** токены за добавление/верификацию POI · premium-функции за токены (фильтры, аналитика, рейтинги) · DAO для категорий и политик · affiliate для провайдеров (хостелы, отели, сервисы).

### 🔐 Web3 & Onboarding (кошельки)
- **Custodial** — скрытый кошелёк, генерируется на сервере на Ruby (`OpenSSL::PKey::EC` secp256k1 + keccak256 + EIP-55, [`Crypto::Ethereum`](lib/crypto/ethereum.rb:1), без новых гемов); приватный ключ шифруется `ActiveSupport::MessageEncryptor` (`WalletService`). Zero-Friction UX: пользователь не взаимодействует с Web3 на старте.
- **External** — продвинутый пользователь подключает свой кошелёк (**MetaMask / hot-wallet**) и подписывает сам; **WalletConnect — на будущее**.
- **`viem` — только фронтенд** (npm, [`package.json`](package.json:23)): EIP-2771 sponsored-транзакции, Contract Mgmt, чтение баланса ERC-20. Генерация ключей на сервере к viem отношения не имеет.
- **DeFi-интеграция:** off-chain леджер `UserReward` + `TokenTransaction` зачисляется за активность → доступ к premium. On-chain отправка через `TokenTransactionService.relay!` (контракты задеплоены, см. `.env`).

---

## ⚙️ Единый поток данных (Database-Triggered Workflow)

**Эталонная цепочка.** Любое изменение состояния проходит через неё; Reflex/Controller НЕ рендерит DOM после сохранения — UI обновляет ТОЛЬКО Broadcaster через `VersionObserverJob`.

```
Stimulus → Reflex (morph :nothing + Pundit) → Service (бизнес-логика, save! в транзакции)
   → PostgreSQL + PaperTrail → VersionObserverJob → Broadcaster (inner_html)
   → CableReady → ActionCable (SolidCable) → DOM
```

### Строгие правила слоёв
| Слой | Делает | Запрещено |
|------|--------|-----------|
| Controller | Доступ (Pundit) + рендер + данные вкладок + pagy | Логика |
| Reflex | Мост UI→Service: `morph :nothing` + authorize + делегирование | Рендерить DOM после сохранения |
| Service | Бизнес-логика, `save!`/`update!` в транзакции | — |
| Model | Только данные | Логика рассылок |
| Broadcaster | Рендер зон + `inner_html` + broadcast | `morph`, `update_all` |
| VersionObserverJob | Маршрутизация по `item_type` → `XxxBroadcaster.call` | — |
| ViewComponent | Только презентация (sidecar 7 файлов, 4 локали) | partials, хардкод текста |

### Практические правила (обязательны)
- **Зарезервированные ключи StimulusReflex** (`id`, `params`, `selectors`, `morph`, `attrs`, `flash`, `event`, `permanent_attribute_name`) — никогда top-level в `this.stimulate`; используй неймспейсные ключи или `{ params: {...} }`; из FormData удаляй `id`.
- **Broadcaster использует `inner_html`, не `morph`** (morph падает на `undefined.dispatchEvent`).
- **Контейнер-цель отдельно от содержимого:** селектор `[data-...]` — на обёртке в шаблоне страницы, НЕ на корне компонента.
- **Нормализация параметров:** `deep_symbolize_keys(params)` в Reflex перед Service.
- **Аудит:** `update!`/`save!` создают версии → Broadcast; `update_all` запрещён для данных с аудитом (в т.ч. реордер).
- **Клиент CableReady:** операции по одной (`forEach` + `try/catch`), пропуск отсутствующих селекторов.
- **Вложенные ViewComponent из job:** только `<%= render %>`/`helpers.render` (view_context); вложенный `ApplicationController.render` запрещён в SolidQueue worker. Per-entry `rescue` (см. `AuditLogComponent#render_entries_html`).
- **Broadcast из worker (`bin/jobs`):** инициализировать ActionCable PubSub до `SolidQueue::Cli.start` — `ActionCable.server.config.cable = { "adapter" => "solid_cable" }` (СТРОКОВЫЙ ключ), затем `ActionCable.server.pubsub`.
- **`pagy()` в Broadcaster:** в worker нет `request` → mock: `def request; @request ||= ActionDispatch::Request.new({}); end`.
- **Чекбоксы (Rails `check_box`):** hidden(value=0)+checkbox с одним `name`. В JS выбирай `input[name='...'][type='checkbox']`.
- **Сценарий «А создал, Б видит»:** А — фазы 1–2 + синхронный redirect + тост; Б — фазы 3–4 через broadcast без перезагрузки.

---

## 📡 Каналы и доставка

Всё через WebSocket — нет данных в JSON-ответе контроллера.
- **`UserChannel`** — `user_<id>` (личный: профиль, тосты, ответы, статус своей точки) + `pois_map` (общий карты: `poi:reload-features`, live-маркер/сайдбар). Noticed (`stream: :user_stream` → `user_<id>`) продолжает работать.
- **`AdminChannel`** (роли `admin` И `moderator`) — `admin_<id>` (личный: результат своих рефлексов) + `admin_feed` (общий админки: POI, юзеры, комментарии, категории, настройки, дашборд).

**SolidCable** — database-backed адаптер ActionCable (PostgreSQL вместо Redis), позволяющий масштабировать несколько Rails-процессов без отдельной инфраструктуры.

---

## 🗂 Единый паттерн админ-сущности

Одна админ-сущность (User, Poi, Setting, PoiCategory…) реализуется по единому шаблону (детали — в инструкциях для ИИ `.roo/rules/03-COMPONENT-REFERENCE.md`).
1. **Компоненты** (sidecar, полный набор): `Admin/<entity>/TableComponent`+`RowComponent` (Index); `<entity>/ShowComponent` + отдельный компонент на каждый таб; `EditComponent`. Селектор-цель — на обёртке страницы, не на корне компонента.
2. **Reflex** (`app/reflexes/admin/<entity>_reflex.rb`): create/update/destroy → `morph :nothing` + `deep_symbolize_keys` + `authorize_with_pundit!` → Service → success/error; filter/page — чтение + `inner_html` + broadcast.
3. **Service**: `save!` в транзакции; `update!`, не `update_all`; `audit_versions`.
4. **Broadcaster**: `inner_html` по селектору-обёртке, каждая зона в `rescue` → `admin_feed`.
5. **Канал**: `AdminChannel` на `admin_<id>` + `admin_feed`.
6. **VersionObserverJob**: ветка `handle_<model>_update` → `XxxBroadcaster.call`.
7. **Живой аудит**: единый `Ui::AuditEntryComponent` (читаемый JSONB, fallback на `version.object`); whodunnit гарантирован в `ApplicationReflex#before_reflex` + сервисный слой; активы вне модели (иконки) — audit-only PaperTrail-версии.
8. **Дочерний CRUD** встроен в edit-форму (модалка по `Ui::ConfirmDialogComponent`); на странице ровно один контейнер-цель.
9. **Формы (чекбоксы):** Rails `check_box` = hidden(value=0)+checkbox с одним `name`; JS выбирает `input[name='...'][type='checkbox']`.

---

## 🏛 Архитектурные решения

| Решение | Обоснование |
|---------|-------------|
| Database-Triggered Workflow | PaperTrail → VersionObserverJob → Broadcaster → CableReady; БД = источник правды |
| StimulusReflex + CableReady | WebSocket-first, без JSON API; Reflex не рендерит DOM после сохранения |
| Sidecar ViewComponents | Изоляция шаблонов/стилей/JS, 4 локали, запрет partials |
| Единая палитра UI | `@utility bg-success/bg-error/bg-warning/bg-info/text-text` в `@theme`; карточки/вкладки/навбар `bg-linear-to-br from-primary/5 to-secondary/10` |
| Ленивые Stimulus-контроллеры | Sidecar-контроллеры по требованию (`_components_lazy.js`), базовый `ApplicationController` |
| PostGIS | Пространственные запросы (bounds, radius, `ST_DWithin`) |
| Proximity Check (100м) | Антифрод для комментариев и голосования через `ST_DWithin` |
| Предложения правок (консенсус 100м) | Применение по автору / независимым локальным юзерам / репутации вместо прямых записей |
| ERC-20 (TFT) геймификация | Utility-токен: награды, верификация, premium |
| EIP-2771 | Спонсированные транзакции — газ платит платформа |
| TON Cross-chain Bridge | Lock ERC-20 → Mint Jetton для экосистемы Telegram |
| SolidQueue вместо Sidekiq | Zero Redis (SolidQueue/SolidCache/SolidCable) |
| PWA + Telegram Mini App | Вместо нативных приложений — охват, бюджет, гранты TON Foundation |

---

## 🏆 Токеномика TFT

- **Лимит эмиссии:** 1 000 000 000 TFT (18 decimals), [`TravelFiToken.sol`](contracts/TravelFiToken.sol:31) `MAX_SUPPLY`. **No burn** — TFT циркулируют в замкнутом контуре (активность → premium/верификация → обратно в оборот).
- **Utility:** награды, репутация (бейджи, уровни от **вклада пользователя**, не `token_balance`), премиум-фильтры, приоритетная верификация, DAO-голосование.
- **Продажа (crowdsale) — отдельная юридически выверенная сущность**, не входит в грант.
- **Кругооборот:** Эмитент выпускает и распределяет разово → пауза. Дальше работают только Кассир (`TravelFiCrowdsale`) и Награды (`TravelFiRewards`). Награды без локдейса (регистрация, реферал новичку) или **с vesting** (`lockDays`; остальные + реферальный бонус реферера — антифрод). Лок считается на лету (`updated_at + lock_days`).
- **Двухэтапное on-chain начисление:** off-chain (`UserReward` + `TokenTransaction`) сразу → кнопка «Забрать награды» (или авто-claim) → одна on-chain отправка на custodial-кошелёк. `TokenTransactionRelayJob` сериализован по оператору (`limits_concurrency`); `TokenTransactionRetryJob` переотправляет упавшие; `sendRewardBatch` для акций.
- **Геймификация:** награды — регистрация 10, реферал (реферер) 5 (vesting), реферал (новичок) 5, POI 20, фото 5, комментарий 5, голос 2. Бейджи — `registration_complete`, `first_poi`, `contributor`, `explorer`, `recruiter`, `veteran`. Конфиг в `Setting.gamification_config` (правится в админке, без редеплоя). `GamificationService.revoke!` — глобальный отзыв не отправленных начислений.

---

## 🗳️ Community Moderation (голосования)

Полиморфный `Vote` (POI/фото/комментарий), live-счётчики через `VoteBroadcaster`/`PoiBroadcaster` (`inner_html`). **Строгая семантика:** `poi.status` ставит ТОЛЬКО админ (`pending` не отображается и не голосуется); голоса юзеров НЕ меняют статус и видимость — только вешают бейджи на уже видимые точки (`ups >= threshold` → «Одобрено сообществом», `downs >= threshold` → «Отклонено сообществом»). Конфликт решает `net = ups - downs`; один юзер — один голос (unique index `[votable_type, votable_id, user_id]`), повторное голосование переключает value. **Анти-фрод:** `VotePolicy` — залогинен, не автор, в пределах 100м. `suspended`/`banned` — решает ТОЛЬКО админ.

---

## ✏️ Предложения правок (консенсус 100м)

Надстройка над `Vote` + `ReputationService`. Прямая правка — только автору точки в окно авторства; остальные в 100м создают **«предложение правки»** (Suggested Edit), применяемое по **консенсусу**. Трёхслойный контроль: **Quick Toggles** (любой в 100м через Vote), **Attributes** (только через `SuggestedEdit` + консенсус), **Locked** (`coordinates`, `poi_category_id`, `slug`, `status` — только админ/модератор; обычный юзер — «Сообщить об ошибке»). Модель `SuggestedEdit` + `suggested_edit_confirmations`. Применение, если: подтвердил автор, или `confirmed_by.size + 1` ≥ порога, или репутация предлагающего ≥ порога. Авто-экспирация через `SuggestedEditExpiryJob`.

---

## 📦 Стандарты разработки

### ViewComponent (Sidecar Subdirectory)
Полное описание — в [`.roo/rules/01-INSTRUCTIONS.md`](.roo/rules/01-INSTRUCTIONS.md) и [`.roo/rules/03-COMPONENT-REFERENCE.md`](.roo/rules/03-COMPONENT-REFERENCE.md). Кратко: класс `XxxComponent < ApplicationComponent` (НЕ module-обёртки, НЕ `ViewComponent::Base`); sidecar-папка с одноимённым именем (`html.erb` + `css` + `controller.js` + 4 yml) — **полный набор, всегда**; корневой тег `data-controller="kebab-case-name"`; partial'ы и инлайн `<script>`/`<style>` запрещены; **Lookbook-превью обязательно**.

### Live-комментарии (без дублей/вложенного HTML)
`Comments::CommentComponent` — чистая обёртка с `[data-comment-content]` + `[data-comment-children]`; контент в `Comments::CommentContentComponent`. `PoiCommentBroadcaster` вставляет корни/ответы; `:update` = `inner_html`. `VersionObserverJob#children_count_only_changed?` подавляет broadcast при изменении только `children_count`. Метка «(изменено {кем} {когда})» читает последнюю UPDATE-версию, менявшую `body`; после live-правки бродкастер шлёт `poi:comment-updated` → `refreshPermissions()`. **Ограничение взаимодействия:** комментирование/голосование/фото требуют активного статуса (`UserAccessService.can_interact?`).

### Стиль, i18n, комментарии
Только зелено-голубая гамма Tailwind (`emerald`, `teal`, `sky`); иконки — только MDI с комментарием класса. 4 локали; переводы в sidecar YAML, относительные ключи `t(".key")`; хардкод запрещён. Каждый метод документируется комментарием непосредственно перед объявлением.

---

## 📨 Уведомления и фоновые задачи

- **Noticed** — одно событие, несколько каналов (database + email + action_cable + web_push).
- **SolidQueue** — database-backed очередь (без Redis); worker'ы в `bin/jobs`. `prepared_statements: false` в [`config/database.yml`](config/database.yml:1) предотвращает Segmentation Fault pg; вторичные БД используют `postgis`-адаптер с `schema_search_path: public,postgis`.
- **SolidCache** — инфраструктура настроена, **кэширование временно отключено в коде** (исключает stale при broadcast-морфах). Возвращать точечно: статичные части ShowComponent ключ `[category, I18n.locale]`; агрегаты с зависимостью от коллекции; НЕ кэшировать формы. Конфиг `config/cache.yml` (256MB).
- **SolidQueueDashboard** — веб-интерфейс мониторинга очередей, статусов, повторного запуска упавших.
- **ReverseGeocodingService** — Nominatim (1 запрос/сек).
- **AiService** — OpenAI-совместимые API (OpenAI/DeepSeek через ENV): токсичность, перевод недостающих ключей, AI-рекомендации (Premium). Реализация — TODO.
- **Ransack** — поиск и фильтрация из параметров запроса без ручного SQL.

---

## 🗄️ Данные и аудит

- **PaperTrail** — полное версионирование (что/кто/когда), триггер всех последующих действий (notifications, broadcasts).
- **PostgreSQL + PostGIS** — географические типы, пространственные запросы (радиус, маршрут).
- **Devise** — аутентификация (email + OAuth), bcrypt, `current_user`, защита маршрутов.

> Версионирование: используй `git log` для истории изменений. Статусы → [`docs/ROADMAP_ru.md`](docs/ROADMAP_ru.md), оценки → [`docs/MILESTONES_ru.md`](docs/MILESTONES_ru.md), долги → [`docs/TECH-DEBTS_ru.md`](docs/TECH-DEBTS_ru.md).
