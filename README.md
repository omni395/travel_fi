# Travel Fi — Architecture & System Design

Travel Fi is an **open, community-driven humanitarian safety and civic infrastructure platform** — a map of the places essential for daily life and safety: drinking water, public toilets and showers, free charging, safe overnight spots, first-aid and pharmacy points. Built for **travelers and city residents alike**, it doubles as aid infrastructure for refugees, displaced people and families with children. Web3 entry is **low-friction**: a custodial wallet is created invisibly at registration, tokens (TFT) reward contribution, and an optional path lets advanced users connect their own wallet. Positioned as **Digital Public Goods (DPG)** — open infrastructure for public benefit.

Architecture — Rails 8.1, WebSocket-first: asynchronous updates via ActionCable (SolidCable), background jobs via SolidQueue, cache infrastructure SolidCache (caching in code **temporarily disabled**), audit via PaperTrail.

> Demo: https://noneternally-approbative-rosanne.ngrok-free.dev/ (admin@example.com/12345678 launching the server by agreement)

> Promo-demo - https://drive.google.com/file/d/1-WECv_pAtkrJqNUK_LF9o1pbySfmNgFx/view?usp=drive_link

> Youtube - https://youtu.be/R1NnzuvNBAU

> Github Repo - https://github.com/omni395/travel_fi

> Support Travel Fi on Giveth: https://giveth.io/project/travel-fi
> Support Travel Fi on Artizen: https://artizen.fund/index/p/travel-fi
> Support Travel Fi on Karmahq: https://www.karmahq.org/project/travel-fi

> **Document set:** product status by section → [`ROADMAP.md`](ROADMAP.md); grant estimate (what to build + time + cost) → [`MILESTONES.md`](MILESTONES.md); debts register → [`TECH-DEBTS.md`](TECH-DEBTS.md).

---

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
| **Job Dashboard** | SolidQueueDashboard - https://github.com/akodkod/solid-queue-dashboard |
| **Caching** | SolidCache (infrastructure; **caching temporarily disabled** in code) |
| **Search & Filtering** | Ransack |
| **Gamification** | Custom system: TFT tokens + badges; levels — from user contribution (not `token_balance`) |
| **Notifications** | Noticed (database + email + action_cable + web_push) |
| **CSS Framework** | Tailwind CSS, Stimulus-Components |
| **Web3** | viem (frontend), three product contracts plus the EIP-2771 forwarder |

---

## Project Vision & Current State

**Mission:** A community-driven map for travelers and locals—a global platform for sharing critical points of interest (POIs) encountered during travel and in daily life.

**Target Audience:** Budget backpackers, digital nomads, solo travelers from developing countries, van-lifers, as well as local residents who utilize various services and public amenities.

**Key Advantage:** There is no dominant global player in most niches (while Wi-Fi hotspots are covered by apps like WiFi Map and Instabridge, other categories remain largely untapped).

**Positioning (Digital Public Goods):** Travel Fi is an open, community-driven map of the places that matter most for daily life and safety — drinking water points, public toilets and showers, free charging, safe overnight spots, first-aid and pharmacy points, luggage storage. Built for **travelers and city residents alike**, it doubles as humanitarian and civic infrastructure: refugees, displaced people and families with children can find water, help points and shelter-adjacent services, while anyone can add and verify them.
> Web3 is deliberately **low-friction**: a custodial wallet is created invisibly at registration, and tokens (TFT) reward contribution. You don't need to know anything about crypto — just contribute, the "crypto" part stays under the hood, with an optional path for advanced users to connect their own wallet. Positioned as **Digital Public Goods** — open infrastructure for public benefit.

**Current Stage:** Prototype currently in active development. The core architecture is complete, and its technical viability has been proven. The product has not yet launched; work is currently focused on code refinement, logic debugging, and preparing the architecture for production.

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

## 💰 Web3 & Smart Contracts

**Four EVM contract sources** (three product contracts plus the EIP-2771 relay; TFT uses 18 decimals):
- [`000-TravelFiForwarder.sol`](contracts/000-TravelFiForwarder.sol) — OpenZeppelin v5 `ERC2771Forwarder`, the separately deployed relayer for signed gas-sponsored calls.
- [`001-TravelFiToken.sol`](contracts/001-TravelFiToken.sol:13) — **Issuer**: hard supply `MAX_SUPPLY = 1 000 000 000`, one-time distribution, then paused; trusts the configured ERC-2771 forwarder.
- [`002-TravelFiCrowdsale.sol`](contracts/002-TravelFiCrowdsale.sol) — **Cashier**: token buy/sell for ETH/USDT (sell fee — anti-arbitrage), feature payment (Token Spend).
- [`003-TravelFiRewards.sol`](contracts/003-TravelFiRewards.sol) — **Rewards**: operator-authorized payouts from the reward pool; vesting/lock periods are enforced by the backend ledger.

**Gas-sponsored actions:** `000-TravelFiForwarder.sol` executes signed EIP-712 requests; product contracts must validate the forwarded sender and expose the target-trust interface. Reward claims and eligible USDT/ETH cashier calls use signed requests; the operator submits the forward request and pays gas. ETH purchases remain ordinary user transactions: only gas is sponsored for forwarded calls, never the ETH purchase principal. USDT purchases still require an allowance unless the specific USDT deployment supports an authorization method. The current Cashier and Rewards sources do not expose the `isTrustedForwarder(address)` view required by OpenZeppelin's forwarder target validation. That contract-interface change and deployment/configuration of the four contract addresses are prerequisites; deployed instances remain unchanged until separately approved and executed.

**Decimals:** EVM contracts = 18; future TON Jetton = 9 (standard). The bridge maps 9↔18 via a conversion factor — existing contracts are NOT rewritten.

### 🚀 Future Roadmap: Telegram & TON
- **Telegram Mini App** — entry into the ecosystem directly from the messenger (POI map, notifications, TFT) without installing a separate app. **TON Cross-chain Bridge** — TFT moves freely between EVM and TON (lock ERC-20 → mint Jetton), making the token truly cross-chain.
- *Strategic development vector, implemented after Production launch and initial user-base build-up.* → [`MILESTONES.md`](MILESTONES.md) M4.

**Monetization via ERC-20 (TFT):** tokens for adding/verifying POIs · premium features for tokens (filters, analytics, ratings) · DAO for categories and policies · affiliate for providers (hostels, hotels, services).

### 🔐 Web3 & Onboarding (wallets)
- **Custodial** — hidden wallet generated server-side in Ruby (`OpenSSL::PKey::EC` secp256k1 + keccak256 + EIP-55, [`Crypto::Ethereum`](lib/crypto/ethereum.rb:1), no new gems); private key encrypted with `ActiveSupport::MessageEncryptor` (`WalletService`). Zero-Friction UX: the user does not interact with Web3 at the start.
- **External** — the wallet model keeps external and custodial wallets separate. The profile supports **MetaMask and other injected hot wallets**, mobile MetaMask deep links, and **WalletConnect**; private keys are never stored by the server. Once linked, the external wallet can sign EIP-2771 reward claims.
- **`viem` — frontend only** (npm, [`package.json`](package.json:23)): wallet connection, Contract Mgmt, and reading ERC-20 balance. Server-side key generation has nothing to do with viem.
- **DeFi integration:** off-chain ledger `UserReward` + `TokenTransaction` credited for activity → premium access. On-chain sending via `TokenTransactionService.relay!` (contracts deployed, see `.env`).

---

## ⚙️ Unified Data Flow (Database-Triggered Workflow)

**Reference chain.** Any state change goes through it; the Reflex/Controller does NOT render DOM after saving — the UI is updated ONLY by the Broadcaster via `VersionObserverJob`.

```
Stimulus → Reflex (morph :nothing + Pundit) → Service (business logic, save! in transaction)
   → PostgreSQL + PaperTrail → VersionObserverJob → Broadcaster (inner_html)
   → CableReady → ActionCable (SolidCable) → DOM
```

### Strict layer rules
| Layer | Does | Forbidden |
|------|--------|-----------|
| Controller | Access (Pundit) + render + tab data + pagy | Logic |
| Reflex | UI→Service bridge: `morph :nothing` + authorize + delegate | Rendering DOM after saving |
| Service | Business logic, `save!`/`update!` in transaction | — |
| Model | Data only | Broadcast logic |
| Broadcaster | Zone render + `inner_html` + broadcast | `morph`, `update_all` |
| VersionObserverJob | Routing by `item_type` → `XxxBroadcaster.call` | — |
| ViewComponent | Presentation only (sidecar 7 files, 4 locales) | partials, text hardcoding |

### Practical rules (mandatory)
- **StimulusReflex reserved keys** (`id`, `params`, `selectors`, `morph`, `attrs`, `flash`, `event`, `permanent_attribute_name`) — never top-level to `this.stimulate`; use namespaced keys or `{ params: {...} }`; remove `id` from FormData.
- **Broadcaster uses `inner_html`, not `morph`** (morph fails on `undefined.dispatchEvent`).
- **Target container separate from content:** the `[data-...]` selector is on the wrapper in the page template, NOT the component root.
- **Normalize params:** `deep_symbolize_keys(params)` in Reflex before Service.
- **Audit:** `update!`/`save!` create versions → Broadcast; `update_all` is forbidden for audited data (incl. reorders).
- **CableReady client:** apply operations one by one (`forEach` + `try/catch`), skipping missing selectors.
- **Nested ViewComponents from a job:** only `<%= render %>`/`helpers.render` (view_context); `ApplicationController.render` nested is forbidden in a SolidQueue worker. Per-entry `rescue` (see `AuditLogComponent#render_entries_html`).
- **Broadcast from worker (`bin/jobs`):** init ActionCable PubSub before `SolidQueue::Cli.start` — `ActionCable.server.config.cable = { "adapter" => "solid_cable" }` (STRING key), then `ActionCable.server.pubsub`.
- **`pagy()` in Broadcaster:** the worker has no `request` → add mock: `def request; @request ||= ActionDispatch::Request.new({}); end`.
- **Checkboxes (Rails `check_box`):** hidden(value=0)+checkbox with one `name`. In JS select `input[name='...'][type='checkbox']`.
- **Scenario «A creates, B sees»:** A — phases 1–2 + synchronous redirect + toast; B — phases 3–4 via broadcast without reload.

---

## 📡 Channels & delivery

Everything over WebSocket — no data in the controller JSON.
- **`UserChannel`** — `user_<id>` (personal: profile, toasts, replies, own-POI status) + `pois_map` (shared map: `poi:reload-features`, live marker/sidebar). Noticed (`stream: :user_stream` → `user_<id>`) keeps working.
- **`AdminChannel`** (roles `admin` AND `moderator`) — `admin_<id>` (personal: own reflex results) + `admin_feed` (shared admin panel: POI, users, comments, categories, settings, dashboard).

**SolidCable** — database-backed ActionCable adapter (PostgreSQL instead of Redis) allowing multiple Rails processes to scale without extra infrastructure.

---

## 🗂 Unified admin entity pattern

One admin entity (User, Poi, Setting, PoiCategory…) follows one template (details in AI instructions `.roo/rules/03-COMPONENT-REFERENCE.md`).
1. **Components** (sidecar full set): `Admin/<entity>/TableComponent`+`RowComponent` (Index); `<entity>/ShowComponent` + separate component per tab; `EditComponent`. Target selector on the page wrapper, not component root.
2. **Reflex** (`app/reflexes/admin/<entity>_reflex.rb`): create/update/destroy → `morph :nothing` + `deep_symbolize_keys` + `authorize_with_pundit!` → Service → success/error dispatch; filter/page — read + `inner_html` + broadcast.
3. **Service**: `save!` in transaction; `update!` not `update_all`; `audit_versions`.
4. **Broadcaster**: `inner_html` per wrapper selector, each zone in `rescue` → `admin_feed`.
5. **Channel**: `AdminChannel` on `admin_<id>` + `admin_feed`.
6. **VersionObserverJob**: branch `handle_<model>_update` → `XxxBroadcaster.call`.
7. **Live audit**: unified `Ui::AuditEntryComponent` (readable JSONB, fallback to `version.object`); whodunnit guaranteed in `ApplicationReflex#before_reflex` + service layer; non-model assets (icons) logged via audit-only PaperTrail versions.
8. **Child CRUD** embedded in the edit form (modal follows `Ui::ConfirmDialogComponent`); exactly one target container per page.
9. **Forms (checkboxes):** Rails `check_box` = hidden(value=0)+checkbox with one `name`; JS selects `input[name='...'][type='checkbox']`.

---

## 🏛 Architectural decisions

| Decision | Rationale |
|---------|-------------|
| Database-Triggered Workflow | PaperTrail → VersionObserverJob → Broadcaster → CableReady; DB = source of truth |
| StimulusReflex + CableReady | WebSocket-first, no JSON API; Reflex doesn't render DOM after saving |
| Sidecar ViewComponents | Isolation of template/styles/JS, 4 locales, partials forbidden |
| Unified UI palette | `@utility bg-success/bg-error/bg-warning/bg-info/text-text` in `@theme`; cards/tabs/navbar `bg-linear-to-br from-primary/5 to-secondary/10` |
| Lazy Stimulus controllers | Sidecar controllers on demand (`_components_lazy.js`), base `ApplicationController` |
| PostGIS | Spatial queries (bounds, radius, `ST_DWithin`) |
| Proximity Check (100m) | Anti-fraud for comments and voting via `ST_DWithin` |
| Suggested Edits (100m consensus) | Apply by author / independent local users / reputation instead of direct writes |
| ERC-20 (TFT) gamification | Utility token: rewards, verification, premium |
| Reward relay (implemented) / EIP-2771 (backend flow implemented; contract interface and deployment prerequisites remain) | Operator-funded legacy payouts remain available; signed user actions require target trust support and deployment/configuration of the forwarder and product contracts |
| TON Cross-chain Bridge | Lock ERC-20 → Mint Jetton for the Telegram ecosystem |
| SolidQueue instead of Sidekiq | Zero Redis (SolidQueue/SolidCache/SolidCable) |
| PWA + Telegram Mini App | Instead of native apps — reach, budget, TON Foundation grants |

---

## 🏆 TFT Tokenomics

- **Emission limit:** 1 000 000 000 TFT (18 decimals), [`001-TravelFiToken.sol`](contracts/001-TravelFiToken.sol:31) `MAX_SUPPLY`. **No burn** — TFT circulate in a closed loop (activity → premium/verification → back into circulation).
- **Utility:** rewards, reputation (badges, levels from **user contribution**, not `token_balance`), premium filters, priority verification, DAO voting.
- **Sale (crowdsale) — separate legally-vetted entity**, not in the grant.
- **Circulation:** Issuer mints and distributes once → paused. Then only the Cashier (`TravelFiCrowdsale`) and Rewards (`TravelFiRewards`) work. Rewards without lock (registration, newcomer referral) or **with vesting** (`lockDays`; rest + referrer's referral bonus — anti-fraud). Lock computed on the fly (`updated_at + lock_days`).
- **Two-stage on-chain crediting:** off-chain (`UserReward` + `TokenTransaction`) immediately → "Claim rewards" (or auto-claim job) → one on-chain send to the selected reward wallet (linked external first, custodial otherwise). `TokenTransactionRelayJob` serialized by operator (`limits_concurrency`); `TokenTransactionRetryJob` resends failed; `sendRewardBatch` for promotions.
- **Gamification:** rewards — registration 10, referral (referrer) 5 (vesting), referral (newcomer) 5, POI 20, photo 5, comment 5, vote 2. Badges — `registration_complete`, `first_poi`, `contributor`, `explorer`, `recruiter`, `veteran`. Config in `Setting.gamification_config` (admin-editable, no redeploy). `GamificationService.revoke!` — global revoke of not-yet-relayed rewards.

---

## 🗳️ Community Moderation (Voting)

Polymorphic `Vote` (POI/photo/comment), live counters via `VoteBroadcaster`/`PoiBroadcaster` (`inner_html`). **Strict semantics:** `poi.status` is set ONLY by admin (`pending` is neither visible nor votable); user votes NEVER change status or visibility — only attach badges to already-visible POIs (`ups >= threshold` → «Community approved», `downs >= threshold` → «Community rejected»). Conflict resolved by `net = ups - downs`; one user = one vote (unique index `[votable_type, votable_id, user_id]`), re-vote toggles value. **Anti-fraud:** `VotePolicy` — logged in, not the author, within 100m. `suspended`/`banned` — decided ONLY by the admin.

---

## ✏️ Suggested Edits (100m consensus)

An extension over `Vote` + `ReputationService`. Direct edit — only the POI author within the authorship window; everyone else within 100m creates a **Suggested Edit**, applied by **consensus**. Three-layer field control: **Quick Toggles** (anyone within 100m via Vote), **Attributes** (only via `SuggestedEdit` + consensus), **Locked** (`coordinates`, `poi_category_id`, `slug`, `status` — admin/moderator only; regular user — «Report an error»). Model `SuggestedEdit` + `suggested_edit_confirmations`. Apply if: author confirmed, or `confirmed_by.size + 1` ≥ threshold, or proposer reputation ≥ threshold. Auto-expiry via `SuggestedEditExpiryJob`.

---

## 📦 Development standards

### ViewComponent (Sidecar Subdirectory)
Full description in [`.roo/rules/01-INSTRUCTIONS.md`](.roo/rules/01-INSTRUCTIONS.md) and [`.roo/rules/03-COMPONENT-REFERENCE.md`](.roo/rules/03-COMPONENT-REFERENCE.md). Summary: class `XxxComponent < ApplicationComponent` (NOT module wrappers, NOT `ViewComponent::Base`); sidecar folder same name (`html.erb` + `css` + `controller.js` + 4 yml) — **full set, always**; root tag `data-controller="kebab-case-name"`; partials and inline `<script>`/`<style>` forbidden; **Lookbook preview mandatory**.

### Live comments (no duplicated/nested HTML)
`Comments::CommentComponent` — pure wrapper with `[data-comment-content]` + `[data-comment-children]`; content in `Comments::CommentContentComponent`. `PoiCommentBroadcaster` inserts roots/replies; `:update` = `inner_html`. `VersionObserverJob#children_count_only_changed?` suppresses reply-increment broadcasts. Comment and reply counters/events are delivered to the shared `pois_map` stream; after a successful create, the author's personal stream clears only the matching form using a targeted `inner_html` operation. **Limits:** one root comment per user per POI and one reply per user per comment; root comments and replies both receive the current activity reward. Future policy to consider once the community is large enough: reward only comments approved by the community. **"Edited by" label** reads the last UPDATE-version changing `body`; after live edit the broadcaster dispatches `poi:comment-updated` → `refreshPermissions()`. **Interaction gating:** commenting/voting/photo require active status (`UserAccessService.can_interact?`).

### Style, i18n, comments
Only green-blue Tailwind palette (`emerald`, `teal`, `sky`); icons — only MDI with class comment. 4 locales; translations in sidecar YAML, relative keys `t(".key")`; no hardcoding. Every method documented with a comment immediately before the declaration.

---

## 📨 Notifications & background

- **Noticed** — one event, multiple channels (database + email + action_cable + web_push).
- **SolidQueue** — DB-backed queue (no Redis); workers in `bin/jobs`. `prepared_statements: false` in [`config/database.yml`](config/database.yml:1) prevents pg Segmentation Fault; secondary DBs use `postgis` adapter with `schema_search_path: public,postgis`.
- **SolidCache** — infra configured, **caching temporarily disabled in code** (avoids stale during broadcast morphs). Restore selectively: static ShowComponent parts key `[category, I18n.locale]`; aggregates with collection dependency; do NOT cache forms. Config `config/cache.yml` (256MB).
- **SolidQueueDashboard** — web UI for monitoring queues, statuses, restarting failed jobs.
- **ReverseGeocodingService** — Nominatim (1 req/sec).
- **AiService** — OpenAI-compatible (OpenAI/DeepSeek via ENV): toxicity, translate missing keys, AI recommendations (Premium). Implementation — TODO.
- **Ransack** — search/filtering from request params without manual SQL.

---

## 🗄️ Data & audit

- **PaperTrail** — full versioning (what/who/when), the trigger for all downstream actions (notifications, broadcasts).
- **PostgreSQL + PostGIS** — geographic types, spatial queries (radius, route).
- **Devise** — auth (email + OAuth), bcrypt, `current_user`, route protection.

> Versioning: use `git log` for change history. Statuses → [`ROADMAP.md`](ROADMAP.md), estimates → [`MILESTONES.md`](MILESTONES.md), debts → [`TECH-DEBTS.md`](TECH-DEBTS.md).
