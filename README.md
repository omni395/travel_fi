# Travel Fi — Architecture & System Design

Travel Fi — Rails 8.1 application for tourism services with DeFi functionality and an ERC-20 token (TFT). Architecture — WebSocket-first: asynchronous updates via ActionCable (SolidCable), background jobs via SolidQueue, cache infrastructure SolidCache (caching in code temporarily disabled), audit via PaperTrail.

> Demo: https://noneternally-approbative-rosanne.ngrok-free.dev/ (launching the server by agreement)

## 🏗️ Technology Stack

| Layer | Components |
|------|-----------|
| **Backend Framework** | Rails 8.1 |
| **Database** | PostgreSQL + PostGIS |
| **Authentication** | Devise + Bcrypt |
| **Authorization** | Pundit + Rolify |
| **Audit & Versioning** | Paper Trail |
| **Frontend** | Stimulus, StimulusReflex |
| **Map Engine** | OpenLayers 10 (clustering, Overlay, PostGIS queries) |
| **Realtime** | ActionCable, SolidCable, CableReady |
| **Background Jobs** | SolidQueue |
| **Job Dashboard** | SolidQueueDashboard |
| **Caching** | SolidCache (infrastructure; cache disabled in code) |
| **Search & Filtering** | Ransack |
| **Gamification** | Custom system: TFT tokens + badges; levels — from `token_balance` |
| **Notifications** | Noticed (database + email + action_cable + web_push) |
| **CSS Framework** | Tailwind CSS, Stimulus-Components |
| **Web3** | viem |

---

## Project Vision & Current State

**Mission:** A community-driven map for travelers — a global platform for sharing POIs (Points of Interest) critical during travel.

**Target audience:** Budget backpackers, Digital nomads, Solo travelers from developing countries, Vanlife travelers.

**Key advantage:** There is no single strong global player in most niches (WiFi spots are occupied by WiFi Map/Instabridge, the rest are blank spots).

**Current Project Stage:**
At present, Travel Fi is a prototype at the stage of active development. A basic architectural foundation has been implemented, proving the technical viability of the concept. The prototype is not a finished product and requires codebase refinement, logic debugging, and final preparation of the architecture for Production launch.

## 📍 POI Categories (from the most in-demand)

1. **Places to buy prepaid SIM and eSIM kiosks** — no specialized app; filter by tariffs, 24/7, proximity to the airport.
2. **Public toilets + showers** — competitors (Flush, SitOrSquat) are narrow; innovation: combo + photos + cleanliness rating + accessibility.
3. **Free water refill points (refill + fountains)** — competitors are weak; viral tracker "how much plastic you saved".
4. **Public showers and laundries** — Park4Night/iOverlander have them as a side feature; schedule, price, access for hotel guests.
5. **Luggage storage** — paid networks (Radical Storage/Bounce); community option (cafes/hostels) — free.
6. **Charging points and outlets** — filter by type (slow/fast), WiFi availability, working outlets.
7. **ATMs with minimal fees + currency exchanges** — ATM Fee Saver is not on a live map; user-reported rates.
8. **Free parking / overnight spots** — extension to all types of transport.
9. **24/7 pharmacies + first aid points** — critical in Asia/LatAm/Africa; medication availability, languages.
10. **Bonus lifehacks** — charging in coworking spaces, pet-friendly, LGBTQ+-safe, free food points.

## 💰 Web3 Integration & Smart Contracts

- **Testnet Status:** The TFT smart contract is written, deployed, and verified in the testnet.
- **Gasless Transactions:** The contract implements a gasless architecture for the end user (Gasless / Meta-transactions).
- **Backend Integration:** The Rails backend (`Crypto::Ethereum`) acts as a Relayer (or interacts with Biconomy/Paymaster). The backend only signs and broadcasts transactions, without shifting gas payments onto users' internal wallets.

### 🚀 Future Roadmap: Telegram & TON

**Telegram Mini App** — a strategic channel for additional user acquisition after the launch of the main application: entry into the ecosystem directly from the messenger (POI map, notifications, TFT tokens) without installing a separate app — where the audience already lives.

**TON Cross-chain Bridge** — a bridge connecting the two networks together: TFT tokens move freely between the EVM network and the TON blockchain through the bridge (lock ERC-20 → mint Jetton). This connects the platform's on-chain economy with the Telegram/TON ecosystem and makes the token truly cross-chain.

*Note: this functionality is a strategic development vector and will be implemented at the stage after Production launch and building the initial user base.*

**Monetization via ERC-20 (TFT):**
- Users get tokens for adding/verifying POIs
- Premium features for tokens (filters, analytics, ratings)
- DAO for managing categories and policies
- Affiliate for providers (hostels, hotels, services)

### 🔐 Web3 & Onboarding (Custodial / Embedded Wallet)
- **Automatic wallet creation:** upon successful registration/confirmation the service generates a hidden (custodial) wallet **in Ruby** — `OpenSSL::PKey::EC` (secp256k1) + a custom keccak256 implementation + EIP-55 (module [`Crypto::Ethereum`](lib/crypto/ethereum.rb:1), no new gems). The private key is encrypted with `ActiveSupport::MessageEncryptor` (`WalletService`).
- **`viem` — frontend only** (npm, [`package.json`](package.json:23)): EIP-2771 sponsored transactions, Contract Mgmt, reading ERC-20 balance. Server-side key generation has nothing to do with viem.
- **Zero-Friction UX:** the user does not interact with the Web3 interface at the start — token crediting/debiting is seamless.
- **DeFi integration:** tokens are credited to the wallet (off-chain ledger `UserReward`) for activity → access to premium features. On-chain sending — via `TokenTransactionService.relay!` (contracts deployed, see `.env`).

---

## ⚙️ Unified Data Flow (Database-Triggered Workflow)

> **Architecture reference.** Any state change goes through this chain. The Reflex/Controller does NOT render DOM after saving — the UI is updated ONLY by the Broadcaster via `VersionObserverJob`. Following the chain guarantees live-updating in all subscribed browsers (the initiator and everyone else).

### Phase 1 — INPUT (browser)
1. **Stimulus controller** (component sidecar) intercepts the event (click/input)
2. `this.stimulate("XxxReflex#action", params)` — RPC over WebSocket
3. **Reflex**: `current_user` → `morph :nothing` (cancels full re-render) → `deep_symbolize_keys(params)` → `authorize_with_pundit!(record, :action?)`
4. Reflex **only delegates** to the Service. Zero logic in the reflex.

### Phase 2 — STATE (PostgreSQL)
5. **Service**: all business logic + `Model.save!`/`update!` **inside a transaction**
6. **PaperTrail** creates a `Version` (event, `whodunnit` = current_user.id, `object_changes`)
7. `after_commit :broadcast_changes` → `VersionObserverJob.perform_later(version.id)`

### Phase 3 — ASYNCHRONOUS DISTRIBUTION (SolidQueue)
8. **VersionObserverJob**: parses `item_type` → branch `handle_<model>_update` → calls `XxxBroadcaster.call`
9. **Broadcaster**: renders zones (ViewComponent via `helpers.render`) → `cable_ready["AdminChannel"].inner_html(selector:, html:)` by wrapper selectors
10. `.broadcast` → ActionCable (**SolidCable**) → stream

### Phase 4 — DELIVERY (browsers A and B)
11. The client is subscribed to the channel (`AdminChannel`/`user_N`) → `received` applies operations **one by one** (`forEach` + `try/catch`, skipping missing selectors)
12. DOM updates **selectively** (inner_html by wrappers) — without reload

### Strict layer rules
| Layer | Does | Forbidden |
|------|--------|-----------|
| Controller | Only access (Pundit) + page render + tab data + pagy | Logic |
| Reflex | UI→Service bridge: `morph :nothing` + authorize + delegation | Rendering DOM after saving |
| Service | Business logic, `save!`/`update!` in transaction | — |
| Model | Data only | Broadcast logic |
| Broadcaster | Zone render + `inner_html` + broadcast | `morph`, `update_all` |
| VersionObserverJob | Routing by `item_type` | — |
| ViewComponent | Presentation only (sidecar 7 files, 4 locales) | partials, text hardcoding |

### Practical integration rules (mandatory)
- **StimulusReflex reserved keys** (`id`, `params`, `selectors`, `morph`, `attrs`, `flash`, `event`, `permanent_attribute_name`) cannot be passed top-level to `this.stimulate` — the object becomes options, `args` arrives empty. Use namespaced keys (`field_id`) or `{ params: {...} }`; remove `id` from FormData.
- **Reflex does not render DOM after saving** — only `morph :nothing` + Service. Selector morph — read-only (pagination/filters).
- **Broadcaster uses `inner_html`, not `morph`** — `morph` fails on `undefined.dispatchEvent` (`parent.children[idx]`).
- **Target container separate from content:** the `[data-...]` selector is on the wrapper in the page template, NOT on the component root (otherwise nesting on `inner_html`).
- **Parameter normalization:** in Reflex `deep_symbolize_keys(params)` before Service (string keys from JS).
- **Audit and bulk updates:** `update!`/`save!` (versions → Broadcast); `update_all` is forbidden for audited data (including reordering positions).
- **CableReady client handling:** in `received` operations one by one (`forEach` + `try/catch`), skipping missing selectors.
- **Rendering nested ViewComponents in Broadcaster (SolidQueue worker):** only `<%= render %>`/`helpers.render` (view_context). Nested `ApplicationController.render` is forbidden — fails in the job, the zone is silently not sent. Per-entry `rescue` (see `AuditLogComponent#render_entries_html`).
- **Broadcast from worker (`bin/jobs`):** initialize ActionCable PubSub before `SolidQueue::Cli.start` — `ActionCable.server.config.cable = { "adapter" => "solid_cable" }` (STRING key; symbol `:adapter` → default `"redis"` → `Redis::CannotConnectError`), then `ActionCable.server.pubsub`.
- **`pagy()` in Broadcaster:** the worker has no `request` → `NameError: request`. Add a mock: `def request; @request ||= ActionDispatch::Request.new({}); end`.
- **Checkboxes (Rails `check_box`):** hidden(value=0)+checkbox with one `name`. In JS select `input[name='...'][type='checkbox']`, otherwise the hidden input (false) is always read.

### Scenario "A created, B sees"
- **A:** Phases 1–2 + synchronous `redirect_to` (A only) + toast to the initiator (`dispatch_event`)
- **B:** Phases 3–4: job → broadcaster → `AdminChannel` → all subscribed admins receive `inner_html` without reload

---

## 📡 Channels and delivery (ActionCable Channels)

Everything is sent over WebSocket — no data in the controller's JSON response.

**Personal channel:** each user is subscribed to `user_<id>` (`UserChannel`).
- `user_100` / `user_200` / `user_N` — personal updates and notifications (including admins as regular users).

**Admin channel:** `AdminChannel` — subscription for roles `admin` AND `moderator` (moderator has edit rights in policies).
- Live admin updates (category fields, audit feed, statistics) are sent to `AdminChannel` (see "Unified admin entity pattern").

**ActionCable** — Rails WebSocket infrastructure: long-lived connection, the server sends messages to all browsers subscribed to the channel.

**SolidCable** — database-backed ActionCable adapter: messages in PostgreSQL instead of Redis; allows scaling multiple Rails processes without separate infrastructure (process 1 sent → process 2 delivered to the browser).

---

## 🗂 Unified admin entity pattern (for quick admin extension)

One admin entity (User, Poi, Setting, PoiCategory…) is implemented using a unified template:

### 1. Components (Sidecar, full set: rb + html.erb + css + controller.js + 4 yml)
- **Index**: `Admin/<entity>/TableComponent` + `RowComponent`.
- **Show**: `Admin/<entity>/<entity>/ShowComponent` + a separate component for EACH tab (`FieldsListComponent`, `PoisListComponent`, `AuditLogComponent`, `ActivityComponent`).
- **Edit**: `Admin/<entity>/<entity>/EditComponent`.
- The target container (`[data-...]`) is on the wrapper in `show.html.erb`, the component root is without it.

### 2. Reflex (`app/reflexes/admin/<entity>_reflex.rb`)
- `create` / `update` / `destroy` — `morph :nothing` → `deep_symbolize_keys(params)` → `authorize_with_pundit!` → Service → `send_success`/`send_error` (dispatch_event into `user_#{id}`).
- `filter` / `<entity>_page` (pagination) — read, render via `ApplicationController.render(Component)` + `inner_html` + `broadcast`.

### 3. Service (`app/services/<entity>_service.rb`)
- `create` / `update` / `destroy` — `Model.save!` in a transaction; `update!`, not `update_all` (audit).
- `audit_versions(entity:)` — entity versions + related (for deleted — via `object`), safe `parse_version_object`.

### 4. Broadcaster (`app/broadcasters/<entity>_broadcaster.rb`)
- `include CableReady::Broadcaster`, `include Pagy::Method` (+ `request` mock for pagy).
- `broadcast` — render zones one by one (`inner_html` by wrapper selector), each zone in `rescue`.
- Nested ViewComponents from a job — only via `<%= render %>`/`helpers.render`.
- Result: `cable_ready["AdminChannel"]` → `.broadcast`.

### 5. Channel
`AdminChannel` (`app/channels/admin_channel.rb`) — subscription `admin` OR `moderator`.

### 6. VersionObserverJob (`app/jobs/version_observer_job.rb`)
- For each `item_type` — branch `handle_<model>_update(version)` → `XxxBroadcaster.call(<entity>: version.item || version.reify)`.

### 7. Live audit (feed)
- Unified `Ui::AuditEntryComponent` for all entities: `changes` filters "empty→empty", readable JSONB, `field_key_from_version` fallback to `version.object`.
- The audit tab panel — a component with its own Stimulus controller on the root (ancestor controller for pagination), `goToPage` → Reflex `<entity>_page`.

### 8. Forms (checkboxes!)
Rails `check_box` generates a pair of inputs with one `name` (hidden `value="0"` + checkbox). In JS select `input[name='...'][type='checkbox']`, otherwise the hidden input (false) is read. Example: `form.querySelector("[name='poi_category_field[required]'][type='checkbox']")`.

---

## 🏛 Architectural decisions

Recorded decisions. When changing any item — update this section and the instructions (`.roo/rules`).

| Decision | Rationale |
|---------|-------------|
| Database-Triggered Workflow | PaperTrail → VersionObserverJob → Broadcaster → CableReady. DB = Single Source of Truth |
| StimulusReflex + CableReady | WebSocket-first, without JSON API. Reflex does not render DOM after saving |
| Sidecar ViewComponents | Isolation of templates/styles/JS, 4 locales, partials forbidden |
| PostGIS | Spatial queries (bounds, radius, ST_DWithin) |
| Proximity Check (100m) | Anti-fraud for comments and voting via `ST_DWithin` |
| ERC-20 (TFT) gamification | Utility token: rewards for activity, verification, premium |
| EIP-2771 (ERC-2771) | Sponsored transactions — gas is paid by the platform |
| TON Cross-chain Bridge | Lock ERC-20 → Mint Jetton for the Telegram ecosystem |
| SolidQueue instead of Sidekiq | Zero Redis (SolidQueue/SolidCache/SolidCable) |
| PWA + Telegram Mini App | Instead of native apps — reach, budget, TON Foundation grants |

### TFT tokenomics (semi-closed system)
- **Emission limit:** 1 000 000 000 TFT (18 decimals), set in [`travel-fi.sol`](travel-fi.sol) (`MAX_SUPPLY`).
- **Tokens are NOT burned (no burn).** TFT circulate within the platform: credited for activity (POI, photos, comments, referrals), spent on premium services and verification, returned to circulation. Deficit — due to the hard emission limit.
- **Utility mechanics:** rewards, reputation (badges, levels from accumulated TFT), premium filters, priority verification, DAO voting.
- **Sale (crowdsale) — a separate legally vetted entity**, not part of the grant application (regulatory risk).

### 🔄 TFT circulation (conditionally closed system)
The user does not need to know anything about cryptocurrency: custodial wallets sign transactions themselves (gasless, EIP-2771); a "smart" user can connect their own wallet and sign independently. The goal is utility TFT circulation in a closed loop **without mint on the fly and without burn**.

**Contract roles:**
| Contract | Role |
|----------|------|
| **Issuer** (`TravelFiToken`) | Hard issuance `MAX_SUPPLY = 1 000 000 000` (18 decimals). One-time distribution of tokens to the other contracts, then **is paused**. |
| **Cashier** | Token purchase for ETH/USDT (without lock), token sale for ETH/USDT **with a fee** (anti-arbitrage), feature payment (Token Spend). Accepts ETH/USDT and gives/takes TFT. |
| **Rewards** (`TravelFiRewards`) | Issuing rewards for actions (POI, photo, comment, like/verification, etc.) with vesting (`lockDays`). Locked TFT are virtual (internal DB account), transferred on-chain only at `claim`. |

**Cycle:**
1. The Issuer mints `MAX_SUPPLY` and distributes among the contracts → is paused.
2. Then only the **Cashier** and **Rewards** work.
3. The user receives a reward for an action:
   - **without lock** — actions that give tokens immediately for spending (by default: registration and the referral bonus to the newcomer himself, lock=0);
   - **with lock (vesting)** — other rewards (photo, content, votes) **and the referral bonus of the REFERRER**: the referrer receives on-chain tokens only after unlocking by the lock period (anti-fraud against fake registrations). A record older than the lock period (`updated_at + lock_days` has passed) is considered unlocked; before that — locked and displayed as an internal off-chain balance.
4. Enough TFT accumulated → feature purchase (e.g., remove ads before showing a POI) → TFT debited from the balance to the **Cashier**.
5. Token purchase for ETH/USDT — without lock (the Cashier works without blocking): ETH/USDT to the cashier's wallet, TFT to the user's balance.
6. Token sale for ETH/USDT → platform fee (anti-arbitrage), the rest of the TFT is debited, ETH/USDT returned.
7. This is how **circulation** of tokens happens in a closed loop.
8. UX: the custodial wallet signs transactions itself (seamless for the "non-crypto" user); an advanced user connects their own wallet and signs independently.

**On-chain crediting (two-stage):** off-chain crediting (`UserReward` + `TokenTransaction`) immediately → by the "Claim rewards" button (or auto-claim job) one on-chain send → real TFT to the custodial wallet. The lock period is computed on the fly for the record (`updated_at + lock_days`), there is no separate field; the "received" marker is boolean. Registration and the newcomer bonus — sent immediately (lock=0); the referrer's referral bonus — by the lock period (vesting, anti-fraud). The sending (`TokenTransactionRelayJob`) is serialized by operator (`limits_concurrency`) to avoid nonce conflicts during parallel relay; failed transactions (`status: failed`) are periodically resent by `TokenTransactionRetryJob` (recurring). `sendRewardBatch` — for promotions/bulk rewards.

### Open technical debts
- [ ] **`ContractSnapshot` (contract monitoring)** — wishlist: model (`contract_type`, `data jsonb`, `created_at`) with rotation for tracking contract state. There is no monitoring code — only on-chain sending via `TokenTransactionService.relay!`.
- [ ] **Targeted caching** — SolidCache is enabled, the cache in code is disabled. Return selectively: ShowComponent `[category, I18n.locale]`, aggregates with collection dependency; do NOT cache forms.
- [ ] **`Ui::ConfirmDialogComponent`** — extract the modal into a separate component, remove the window from `Poi::ShowComponent`/`Poi::FormComponent`.

---

## 📐 System architecture

### The "One entity" principle
- **Model** — data and relations (base only).
- **Service** — the single entry point for business logic.
- **Reflex** — the entry point for UI interactions over WebSocket.
- **Controller** — only access (Pundit), rendering, Pundit policies.
- **Broadcaster** — the layer for delivering interface updates (CableReady).
- **Notification** — notifications (Noticed) with filtering via `Setting`.

### DATABASE as Single Source of Truth
Data in PostgreSQL with history via PaperTrail: transactional (all or nothing), audit of every change, reliability (transaction failed — nothing sent).

---

## 📦 Development standards

### ViewComponent (Sidecar Subdirectory)
Full description — in [`.roo/rules/01-INSTRUCTIONS.md`](.roo/rules/01-INSTRUCTIONS.md) and [`.roo/rules/03-COMPONENT-REFERENCE.md`](.roo/rules/03-COMPONENT-REFERENCE.md). Summary:
- Each component is a class `XxxComponent < ApplicationComponent` (NOT module wrappers, NOT `ViewComponent::Base`).
- Sidecar folder with the same name: `html.erb` + `css` + `controller.js` + 4 yml (en/ru/es/zh) — **full set, always** (even empty JS/CSS).
- Template root tag: `data-controller="kebab-case-name"`.
- Partials are forbidden. Inline `<script>`/`<style>` are forbidden.

### Style and colors
- Only the green-blue Tailwind palette (`emerald`, `teal`, `sky`). Custom styles are forbidden.
- Icons — only MDI, with a comment of the class name (`<%# Icon: mdi-pencil %>`).

### Internationalization
- 4 locales: en, ru, es, zh. Text hardcoding is forbidden.
- Translations — in the component's sidecar YAML, relative keys `t(".key")`. Keys in `config/locales/*.yml` for texts inside a ViewComponent — forbidden.

### Comments
Every method is documented with a comment STRICTLY before the declaration.

---

## 🔌 Main frontend components

### Stimulus
A lightweight framework for browser-Rails interaction. Listens to events (clicks, input), sends signals to Rails, updates the DOM, manages state. Lifecycle: initialization when the element appears in the DOM, cleanup on removal.

### StimulusReflex
Reactive components over WebSocket: the browser sends an action, the server updates the needed parts of the DOM (morphing). Use `this.stimulate("Reflex#method", params)`. **`prevent_refresh!` DOES NOT EXIST** — use `morph :nothing` instead.

### CableReady
A generator of DOM update commands. Transport layer: a command (update/replace/add/remove/notify) is sent over WebSocket and executed by the browser.

---

## 📨 Notifications and background jobs

### Noticed
A multichannel notification system: one notification — multiple channels (Email, SMS/Twilio, Push/WebPush, In-app/WebSocket).

### SolidQueue
Database-backed queue (instead of Sidekiq + Redis). Long operations are stored in the DB, worker processes execute asynchronously.

**DB stability:** in [`config/database.yml`](config/database.yml:1) prepared statements are disabled (`prepared_statements: false`) — this removes the Segmentation Fault (`connect_start`) of the `pg` gem under multithreaded/multiprocess SolidQueue. All secondary DBs (queue/cache/cable) use the `postgis` adapter with `schema_search_path: public,postgis` — a single C-extension connection type in the application (otherwise conflicts).

### SolidCache
Database-backed cache (Redis alternative). Infrastructure is configured, **caching in code is disabled** (to exclude stale during broadcast morphs). When to bring back (selectively): static parts of ShowComponent — key `[category, I18n.locale]`; aggregates — with collection dependency (`[category, category.pois, I18n.locale]`); do NOT cache forms. Configuration: `config/cache.yml` (256MB), `:solid_cache_store` in production, `bin/rails dev:cache` in dev.

### SolidQueueDashboard
Web interface for monitoring queues, job statuses, and restarting failed jobs.

### ReverseGeocodingService
Reverse geocoding (country/city/address by coordinates). API: Nominatim (free, 1 request/sec). File: [`app/services/reverse_geocoding_service.rb`](app/services/reverse_geocoding_service.rb).

### AI services (paid LLM API)
A unified `AiService` (OpenAI-compatible APIs: OpenAI, DeepSeek; switching via ENV). Scenarios: `check_toxicity`, `translate_missing_keys`, AI recommendations (Premium). Implementation — TODO.

### Ransack
Search and filtering of data based on request parameters, without manual SQL.

---

## 🏆 Gamification and TFT tokens

**TOKEN MODEL:** rewards are credited with TFT tokens (not "points").

**Architecture:** the `UserReward` model (`amount` TFT, `action_key`, `wallet_id`) — off-chain crediting ledger; `User#token_balance` = sum of credits; the `GamificationService` service (`award!`, `award_referral!`, `badge_key`, `check_badges!`); badges — the `Gamification` model (event_type `badge`, reputation achievements); config [`config/gamification.yml`](config/gamification.yml) (rewards — TFT tokens, badges — achievements).

**Rewards (TFT):** registration (welcome) 10, referral (referrer) 5 — by vesting lock period (anti-fraud), referral (newcomer) 5 — instantly, POI addition 20, POI photo 5, comment 5, POI vote 2.

**Badges:** `registration_complete`, `first_poi`, `contributor` (10+), `explorer` (5+ cities), `recruiter` (5+ referrals), `veteran` (balance 1000+ TFT).

**I18n:** badge and reward names are localized (en, ru, es, zh).

---

## 🗄️ Data and audit

### Paper Trail
Full versioning of models: WHAT changed (old/new values), WHO (user), WHEN, WHAT happened (create/update/destroy). The trigger for all subsequent actions (notifications, broadcasts).

### PostgreSQL + PostGIS
Main DB + geographic extension: coordinates as geographic types, spatial queries (objects within a radius, on a route).

---

## 🔐 Security

### Devise
Authentication: registration, login, password recovery, sessions. Passwords — bcrypt (irreversible hashing). Provides `current_user`, protection of routes from unauthorized access.
