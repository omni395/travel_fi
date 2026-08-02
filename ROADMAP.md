# Travel Fi — Product Roadmap

> Документ фиксирует архитектурные решения, план развития и ключевые фичи.
> Разделён на 3 блока:
> **Блок 1** — что уже реализовано в кодовой базе (MVP Core).
> **Блок 2** — ближайшие доработки (quick wins, мелкие внедрения, баги).
> **Блок 3** — долгосрочные архитектурные решения и сложные фичи.

---

## БЛОК 1: РЕАЛИЗОВАНО (MVP Core)

### Инфраструктура

- [x] Rails 8.1 + Ruby 3.4.9 + PostgreSQL + PostGIS
- [x] StimulusReflex + CableReady (WebSocket-first)
- [x] SolidQueue + SolidCache + SolidCable (zero Redis)
- [x] Devise + Bcrypt + Pundit + Rolify (auth + авторизация + роли admin/moderator/user)
- [x] PaperTrail — аудит всех 6 моделей (User, Poi, PoiCategory, PoiCategoryField, PoiComment, Setting)
- [x] FriendlyId — slug-based URL
- [x] Pagy — пагинация в связке с CableReady
- [x] 4 локали (en/ru/es/zh) — sidecar YAML в ViewComponents

### Модели и БД

- [x] **User** — Devise, Google OAuth, рефералы, уровни (1-5), статусы, ActiveStorage аватар
- [x] **Poi** — PostGIS point, JSONB name/description (i18n), статусы, source (manual/osm), рейтинг, metadata
- [x] **PoiCategory** — JSONB name/description, OSM-теги, active/position
- [x] **PoiCategoryField** — динамические поля категорий
- [x] **PoiComment** — threaded (parent_id), PaperTrail
- [x] **Setting** — настройки уведомлений per-user
- [x] **Gamification** — баллы (score) + бейджи (badge)
- [x] **Role** — Rolify

### Сервисный слой (15 шт)

- [x] [`UserService`](app/services/user_service.rb) — профиль, Google OAuth, аватар
- [x] [`Admin::UserService`](app/services/admin/user_service.rb) — CRUD пользователей, роли, статусы
- [x] [`PoiService`](app/services/poi_service.rb) — CRUD POI, комментарии, GeoJSON, nearby
- [x] [`PoiCategoryService`](app/services/poi_category_service.rb) — CRUD категорий, поля, reorder
- [x] [`GamificationService`](app/services/gamification_service.rb) — баллы, бейджи, уровни, рефералы
- [x] [`ContractService`](app/services/contract_service.rb) — 26 методов смарт-контрактов
- [x] [`OsmImportService`](app/services/osm_import_service.rb) — импорт из OSM (Overpass API)
- [x] [`ReverseGeocodingService`](app/services/reverse_geocoding_service.rb) — Nominatim
- [x] `PaidAiService` (TODO) — прямые API платных ИИ (HuggingFaceService удалён)
- [x] [`ImageTransformService`](app/services/image_transform_service.rb) — WebP сжатие
- [x] [`VersionObserverJob`](app/jobs/version_observer_job.rb) — Database-Triggered Workflow
- [x] [`UserActivityService`](app/services/user_activity_service.rb) — лента активности
- [x] [`UserAuditLogger`](app/services/user_audit_logger.rb) — аудит login/logout/registration
- [x] [`PaperTrailAuditService`](app/services/paper_trail_audit_service.rb) — централизованный аудит
- [x] [`SettingService`](app/services/setting_service.rb) — CRUD настроек

### WebSocket слой

- [x] **7 Reflex-классов**: PoiReflex, UserReflex, SettingsReflex, Admin::* (4 шт)
- [x] **8 Broadcasters**: PoiBroadcaster, UserBroadcaster, SettingBroadcaster, PoiCategoryBroadcaster, ToastBroadcaster, OsmImportBroadcaster, Admin::DashboardBroadcaster, Admin::UserBroadcaster
- [x] **2 Channels**: UserChannel, AdminChannel
- [x] **Database-Triggered Workflow**: Model.save → PaperTrail → VersionObserverJob → Broadcaster → CableReady → DOM

### UI (40+ ViewComponents, полный sidecar)

- [x] **Ui/***: Card, Btn, Badge, Avatar, Breadcrumbs, Clipboard, ConfirmDialog, Dropdown, Navbar, Pagination, Sidebar, Tooltip, Toast, Tabs
- [x] **Poi/***: Map (OpenLayers 10 + кластеризация), Detail (табы), Filters, Form, ListItem
- [x] **Users/***: ProfileComponent, FormComponent
- [x] **Settings/***: FieldComponent
- [x] **Admin**: Dashboard (статистика), PoiCategories (CRUD + audit), Pois (CRUD + audit), Users (CRUD + audit + wallet)
- [x] **Аудит**: единая запись [`Ui::AuditEntryComponent`](app/components/ui/audit_entry_component.rb) (event/whodunnit/diff, empty state, фильтр «пусто→пусто», читаемый JSONB) + панель таба аудита (компонент со своим Stimulus-контроллером для пагинации, например `Admin::PoiCategories::PoiCategory::AuditLogComponent`); рендер из job через `helpers.render` + per-entry rescue

### Смарт-контракты (Solidity, deployed testnet)

- [x] **TravelFiToken** — ERC-20, max supply 1,000,000 TFT, 18 decimals
- [x] **TravelFiCrowdsale** — buy/sell USDT/ETH
- [x] **TravelFiRewards** — sendReward, claim, revoke, lockDays

### Уведомления (Noticed — написано, не оттестировано)

- [x] [`UserProfileNotification`](app/notifications/user_profile_notification.rb) — database + email + action_cable + web_push delivery
- [x] `Noticed::DeliveryMethods::WebPush` — написан, использует VAPID ключи из `.env`
- [x] `UserMailer` — шаблоны писем (confirmation, reset_password, profile_updated, account_deleted)
- [x] VAPID keys сгенерированы (`.env`)

---

## БЛОК 2: БЛИЖАЙШАЯ ПЕРСПЕКТИВА (Quick Wins)

*Мелкие доработки и баги*

### Исправление табов - ПЕРЕПРОВЕРИТЬ!!!!

- [ ] Исправить работу вкладок [`Ui::TabsComponent`](app/components/ui/tabs_component/) — переключение и рендер содержимого активной вкладки
- [ ] Проверить табы в профиле пользователя админки (активность/аудит) — активная вкладка должна переключаться и подгружать своё содержимое live

### POI: загрузка из админки в категорию - ВАЖНО!!!!!

- [ ] Исправить импорт POI из OSM через админку — сейчас привязка к категории ломается - точки загружаются, но вкладка с пои не обновляется по мере добавления точек или при зкрытии страницы.
- [ ] После импорта POI должны появляться на карте (сейчас visible scope фильтрует по `poi_categories.active`, проверить что категория активна)
- [х] Добавить индикатор прогресса импорта (OsmImportJob уже есть, но UI обратной связи нет)

### POI: добавление на карте и через админку

- [ ] Исправить форму создания POI — reverse geocoding через Nominatim работает, но поля city/country/address не всегда заполняются
- [ ] После создания POI через админку — точка должна сразу появляться на карте (сейчас broadcaster шлёт в `UserChannel`, но карта не перезагружает маркеры)
- [ ] Валидация координат: при создании POI без координат — не показываать кнопку, и показывать понятное сообщение пользователю.

### POI: карточка (детальный просмотр)

- [ ] Проверить работу табов в [`Poi::DetailComponent`](app/components/poi/detail_component/) — инфо/комментарии/мини-карта
- [ ] Комментарии: создание через [`PoiReflex#create_comment`](app/reflexes/poi_reflex.rb:569) — proximity-check (100м) не вызывается, антифрод не работает (работет так что маркер прост овозвращается в пределы круга, в принципе нормально но можно и подправить)
- [ ] После добавления комментария — список должен обновляться live для всех (сейчас только для автора через cable_ready.inner_html)

### POI: попап (мини-карточка) при наведении

- [ ] Попап при ховере на маркер карты — [`Ui::TooltipComponent`](app/components/ui/tooltip_component/) должен показывать фото слева на всю высоту в одной колонке и название + категорию + рейтинг в другой колонке построчно.
- [ ] Сейчас данные для тултипа передаются через `data-poi-*` атрибуты, но сам тултип не рендерится. Исправить OpenLayers overlay или использовать Stimulus-контроллер

### Админка пользователей: баг сохранения

- [x] [`Admin::UsersReflex`](app/reflexes/admin/users_reflex.rb) — при сохранении профиля пользователя в админке возникает ошибка валидации или PaperTrail конфликт
- [x] Проверить [`Admin::UserService#execute_update`](app/services/admin/user_service.rb:138) — `Current.admin_context` устанавливается, но не проверяется в broadcaster'ах
- [x] После сохранения пользователя — список в админке должен обновиться live (сейчас Admin::UserBroadcaster шлёт в UserChannel, а не в AdminChannel)

### Reflex: live-обновление при изменении пользователя

- [ ] [`VersionObserverJob`](app/jobs/version_observer_job.rb) создаёт `UserProfileNotification` и вызывает `UserBroadcaster.call`, но другой админ не видит изменения в live-режиме
- [ ] Причина: все broadcasters шлют в `UserChannel`, но AdminChannel не используется. Нужно разделить стримы — админские события в AdminChannel
- [ ] [`UserBroadcaster`](app/broadcasters/user_broadcaster.rb) — проверить что `cable_ready[UserChannel].morph` отрабатывает для всех окон пользователя

### Смарт-контракт: газ за счёт платформы - ВАЖНО!!!!

- [ ] Сейчас `eth_sendRawTransaction` требует подписанную транзакцию с клиента. Нужно перейти на модель, где мы платим за газ
- [ ] Вариант A: Серверный кошелёк (hot wallet) с ETH балансом — подписываем транзакции на сервере через `eth_signTransaction` / приватный ключ в `ENV`
- [ ] Вариант B: EIP-2771 (ERC-2771) — доверенный forwarder контракт. Пользователь подписывает meta-transaction, мы отправляем и платим газ
- [ ] Реализовать `ContractService.send_transaction_sponsored(…)` — сервер подписывает и отправляет
- [ ] Админка: просмотр баланса hot wallet, пополнение, логи газа

### Скрытый кошелёк при регистрации - ВАЖНО!!!!

- [х] Интеграция библиотеки `viem` для взаимодействия с EVM-сетями.
- [ ] При смене статуса пользователя на `active` (после полной регистрации: email confirmed + Google OAuth + referral) — создать скрытый (custodial) кошелёк
- [ ] Архитектура: `Admin::WalletService.create_hidden_wallet(user)` — генерирует ключи (или через HSM/KMS), сохраняет зашифрованный приватный ключ в `Wallet` модели
- [ ] Модель `Wallet` расширить: `user_id, address, encrypted_private_key, chain_id, created_at`
- [ ] Кошелёк используется для: получения наград (TravelFiRewards), оплаты газа за пользователя (sponsored tx)
- [ ] Пользователь может "вывести" средства на свой MetaMask через `transferOwnership`

### Telegram Mini App + TON cross-chain

- [ ] Telegram Mini App (WebApp) — продумать систему регистрации. интегрировать с сууществующей структурой.
- [ ] Продумать систему регистрации через телеграмм с созданием пользователя в БД.
- [ ] TON кошелёк при регистрации (Tonhub/ Tonkeeper) — создаётся скрытый кошелёк или пользователь подключает свой
- [ ] Cross-chain swap TFT (ERC-20) ↔ TON Jetton — через bridge контракт (Lock/Mint или Atomic Swap)
- [ ] Архитектура: наш TravelFiToken (ERC-20) → Lock-контракт на EVM → Relayer → Mint TFT-Jetton на TON → Telegram кошелёк
- [ ] Грант TON Foundation: DeFi приложение для туризма на TON + Telegram Mini App
- [ ] Регистрация через Telegram: `TelegramAuthService` (проверка HMAC от Telegram WebApp)
- [ ] Уведомления через Telegram Bot API (Twilio не нужен для Telegram)

---

## БЛОК 3: ДОЛГОСРОЧНАЯ ПЕРСПЕКТИВА

*Крупные архитектурные решения. Требуют новых моделей, миграций, сервисов.*

### Система рейтингов (Rating System)

Модель `PoiRating` + PostGIS proximity-check + Pundit policy

- [ ] Модель `PoiRating` (poi_id, user_id, score: 1-5, unique constraint)
- [ ] Proximity-check 100м через `ST_DWithin`
- [ ] Переголосование (update вместо insert)
- [ ] Агрегация: средний рейтинг → `poi.rating`
- [ ] Сортировка POI по рейтингу (Ransack)
- [ ] Топ POI в регионе / в bounds
- [ ] UI: звёзды в деталях POI, в списке, на карте

### Premium-подписка и монетизация (TFT-based)

Модели `Subscription`, `PoiBoost` + Pundit-scoped Ransack + ContractService.burn

- [ ] Модель `PoiBoost` (poi_id, user_id, expires_at, boost_type)
- [ ] Модель `Subscription` (user_id, tier, expires_at, payment_tx_hash)
- [ ] Premium-бейдж `mdi-crown` на карточке POI
- [ ] Premium-сортировка: boost выше в результатах
- [ ] Расширенные фильтры (Premium-only): рейтинг, расстояние, динамические поля
- [ ] Ограничения OSRM маршрутов: Free (7/нед), Starter/Pro/Unlimited за TFT
- [ ] Ограничения импорта OSM: Free (1 город/день), Day Pass, Week Pass, Pro
- [ ] AI-рекомендации (Premium): платный LLM (прямые API платных ИИ, HuggingFace отклонено)
- [ ] Offline-экспорт GPX/CSV: Free (5 POI), Premium (весь регион)
- [ ] Приоритетная верификация за TFT
- [ ] Pundit scope для фильтрации по подписке
- [ ] Сжигание TFT (burn) за премиум-действия

### AI-инфраструктура (единый AiService)

Решение: **единый `AiService`** (прямые API платных ИИ, OpenAI-совместимый endpoint) вместо HuggingFace. Все AI-сценарии идут через один сервис — клиент API, промпты, ключи, лимиты в одной точке. Бизнес-сервисы (комментарии, админка) вызывают его как шаг валидации/обработки, не содержат HTTP-логику.

- [ ] `AiService.check_toxicity(text)` — проверка токсичности комментариев (вызывается из сервиса комментариев перед сохранением)
- [ ] `AiService.translate_missing_keys` — автозаполнение пропущенных ключей переводов в админке (автоматизация заполнения пустых локалей для POI/категорий)
- [ ] API-ключ через `ENV`, провайдер-агностичная обёртка (смена провайдера — правка одного файла). Провайдеры: OpenAI, DeepSeek (`api.deepseek.com`), иные OpenAI-совместимые
- [ ] AI-рекомендации (Premium) — см. раздел Premium

### Web3 интеграция (WalletConnect / MetaMask)

EIP-1193 провайдер (клиент) + ContractService (сервер)

- [ ] Stimulus-контроллер `wallet-controller.js`
- [ ] WalletConnect protocol (QR)
- [ ] Подписание транзакций на клиенте → `eth_sendRawTransaction` (спонсированный газ)
- [ ] UI: баланс TFT/USDT/ETH в профиле
- [ ] UI: покупка TFT (Crowdsale)
- [ ] UI: Claim Reward (Rewards)
- [ ] Админка: управление контрактами (mint/burn/rate/pause)
- [ ] Админка: распределение наград (sendReward/sendRewardBatch)
- [ ] Админка: просмотр балансов и статуса контрактов
- [ ] Покупка стикеров/иконок за TFT
- [ ] Донаты создателям POI

### ContractService: детект изменений через БД-снимки

[`ContractService.detect_changes_for_contract`](app/services/contract_service.rb:857) использует `Rails.cache` как хранилище предыдущего состояния контракта (TTL 2 часа). Это архитектурно неверно: кэш эфемерен и сбрасывается — после простоя > 2 часов все поля ложно считаются changed. Нужно заменить на БД-снимки.

- [ ] Модель `ContractSnapshot` (contract_type, data jsonb, created_at) + миграция
- [ ] `detect_changes_for_contract`: читать последний снимок → сравнить → записать новый (вместо `Rails.cache.read/write`)
- [ ] Инвалидация/ротация старых снимков (keep last N)

### Рекламная система (Ad Network)

Модель `AdCampaign` + таргетинг + оплата в TFT

- [ ] Модель `AdCampaign` (advertiser_id, poi_category_id, budget_tft, geo_bbox, impressions_limit)
- [ ] Interstitial перед карточкой POI
- [ ] Спонсорские POI в сайдбаре
- [ ] Админка: управление кампаниями
- [ ] Таргетинг по категориям и гео
- [ ] Оплата в TFT
- [ ] Статистика: показы, клики, CTR

### Аналитика (Analytics Dashboard)

Chartkick + Groupdate + PaperTrail агрегация

- [ ] Дашборд: активность пользователей (регистрации/логины по дням)
- [ ] Геораспределение POI (карта + таблица по странам/городам)
- [ ] Популярные категории (pie chart)
- [ ] Аналитика просмотров для владельцев POI (PaperTrail)
- [ ] Google Analytics / GTM интеграция

### OSRM Маршрутизация

OSRM сервер (Docker) + PostGIS маршрут + OpenLayers

- [ ] OSRM бэкенд (docker-compose)
- [ ] API: маршрут от пользователя к POI
- [ ] Линия маршрута на карте
- [ ] Расчёт расстояния и времени
- [ ] Кнопка "Построить маршрут" в карточке POI
- [ ] Лимиты: Free (7/нед), Starter/Pro/Unlimited

### Система верификации POI

- [ ] Фото-верификация (user uploads → moderators approve)
- [ ] Community vote (DAO-like за TFT)
- [ ] Бейдж "Verified" на карточке POI
- [ ] Приоритетная верификация за TFT

### City model — нормализация городов

- [ ] Модель `City` с PostGIS геометрией
- [ ] Миграция: `poi.city_id` → FK
- [ ] CRUD городов в админке
- [ ] Авто-определение города при создании POI

### PWA — Offline mode

- [ ] Service Worker кэширование тайлов карты
- [ ] Offline-список POI (IndexedDB)
- [ ] Offline-экспорт GPX/CSV
- [ ] Push-уведомления (Service Worker готов, VAPID ключи есть)

### WhatsApp + Telegram Bot

- [ ] Twilio WhatsApp API — поиск POI через чат-бота
- [ ] Уведомления и маршруты через WhatsApp
- [ ] Подтверждение действий через WhatsApp OTP

### Производительность

- [ ] **Точечное кэширование (вернуть после стабилизации)**: кэш убран из кода, чтобы исключить stale-данные при broadcast-морфах. Возвращать точечно: статичные части ShowComponent — ключ `[category, I18n.locale]` (инвалидация по `updated_at` категории); агрегаты `pois.count` — ключ ОБЯЗАТЕЛЬНО с зависимостью от коллекции POI `[category, category.pois, I18n.locale]`; НЕ кэшировать формы (OsmImportComponent) и блоки со счётчиками POI без ключа по коллекции
- [ ] Кэширование тайлов карты (tile caching)
- [ ] Оптимизация PostGIS запросов (explain analyze, индексы)
- [ ] WebSocket масштабирование (SolidCable clustering)
- [ ] Кэширование GeoJSON через SolidCache

---

## Приоритеты на текущую итерацию

1. **AuditLogComponent** — проверить sidecar, внедрить на Dashboard и Setting
2. **POI: импорт + карта + карточка + попап** — 4 связанные задачи (загрузка из админки, добавление, детали, тултип)
3. **Админка пользователей** — баг сохранения, live-обновление через AdminChannel
4. **Спонсированный газ** — переписать ContractService для оплаты газа платформой
5. **Скрытый кошелёк** — WalletService при статусе active, custodial keys
6. **Telegram Mini App** — архитектура cross-chain TFT↔TON, регистрация через Telegram

---

## Архитектурные решения

| Решение | Обоснование |
|---------|-------------|
| Database-Triggered Workflow | PaperTrail → VersionObserverJob → Broadcaster → CableReady |
| StimulusReflex + CableReady | WebSocket-first, без JSON API |
| Sidecar ViewComponents | Изоляция шаблонов, стилей, JS, 4 локалей |
| PostGIS | Пространственные запросы (bounds, radius, ST_DWithin) |
| Proximity Check (100м) | Антифрод для комментариев и голосования |
| ERC-20 (TFT) геймификация | Дефицит токена + utility |
| EIP-2771 (ERC-2771) | Спонсированные транзакции — газ платит платформа |
| TON Cross-chain Bridge | Lock ERC-20 → Mint Jetton на TON для Telegram экосистемы |
| SolidQueue вместо Sidekiq | Zero Redis |
| PWA + Telegram Mini App | Вместо нативных приложений — охват, бюджет, гранты TON Foundation |

## Известные архитектурные долги (Tech Debt)

### CableReady из SolidQueue worker (cross-process broadcast) — ✅ РЕШЕНО

**Проблема:** broadcast из `bin/jobs` не гарантированно доставлялся клиенту (ActionCable PubSub не инициализирован в worker — SolidQueue не запускает ActionCable middleware).

**Решение (применено в [`bin/jobs`](bin/jobs)):** инициализация ActionCable PubSub до старта SolidQueue Supervisor:
```ruby
ActionCable.server.config.cable = { "adapter" => "solid_cable" }
ActionCable.server.config.logger = Rails.logger
ActionCable.server.pubsub
```
- Ключ `"adapter"` — СТРОКОВЫЙ: `ActionCable::Server::Configuration#pubsub_adapter` делает `cable.fetch("adapter") { "redis" }`; символьный `:adapter` → дефолт `"redis"` → `Redis::CannotConnectError` (проект zero-Redis).
- SolidCable-адаптер Redis не использует: `broadcast` → `SolidCable::Message.broadcast` (INSERT в Postgres `travel_fi_dev_cable`); подключение к cable-БД SolidCable настраивает сам.
- Сопутствующее: `pagy()` в Broadcaster из worker падает на `NameError: request` → в Broadcaster добавлен mock `ActionDispatch::Request` (аналог того, что Reflex получает от StimulusReflex).
