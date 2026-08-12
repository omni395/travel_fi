# Travel Fi — Product Roadmap

> A unified plan by **application sections**: what works, what is in progress, what is planned.
> **Statuses:** `✅` works · `🟡` partial · `🔴` wishlist/planned · `⚠️` bug/debt
> Architecture and instructions — in [`README.md`](README.md:1) and `.roo/rules/` (not duplicated here).

---

## 0. Legend

- **Sections = application pages** (USER SECTION and ADMIN SECTION). Horizontal layers are cross-cutting infrastructure.
- **Each section** has 3 blocks: **Done** (`✅`), **Wishlist** (`🔴`), **Bugs/Debts** (`⚠️`).
- **Routes:** user profile — `/:slug`, admin — `/admin-panel` (see [`config/routes.rb`](config/routes.rb:36)).
- **Chain (Database-Triggered Workflow):** Controller/Reflex → Service (Pundit + save! in a transaction) → PostgreSQL + PaperTrail → VersionObserverJob → Broadcaster (inner_html) → CableReady → ActionCable (SolidCable) → DOM.

---

## 1. Application sections map

```
Travel Fi
├── 👤 USER SECTION          (/:locale/)
│   ├── 2.1 Landing          (/)               🔴 stub
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
│   └── 3.6 Contract Mgmt    🔴 (planned)
├── 4. Horizontal layers
│   ├── 4.1 Auth & Roles     ✅
│   ├── 4.2 Gamification & Web3  🟡
│   ├── 4.3 Realtime infra   ✅
│   ├── 4.4 Audit            ✅
│   ├── 4.5 Notifications    ✅
│   ├── 4.6 i18n / UI        ✅
│   ├── 4.7 PWA / Devices    🟡
│   └── 4.8 CI / Tests / Production  🟡
└── 5. Relations + data flows
```

---

## 2. 👤 USER SECTION

### 2.1 Landing (home)

**Route:** `/` ([`PagesController#index`](app/controllers/pages_controller.rb:10))

**Chain:** PagesController → view (a logged-in user is redirected to `/pois` via `session[:redirected_to_map]`)

**Components:** [`Ui::NavbarComponent`](app/components/ui/navbar_component.rb:1) (shared layout [`app/views/layouts/application.html.erb`](app/views/layouts/application.html.erb:47))

**Status:** 🔴 **Stub** — [`app/views/pages/index.html.erb`](app/views/pages/index.html.erb:1) contains test content.

**Done:**
- ✅ Page route and controller
- ✅ Redirect of a logged-in user to the map (once per session)

**Wishlist:**
- 🔴 Full landing: hero + advantages + CTA "Open map"
- 🔴 Block of popular POI categories (from `PoiCategory.active`)
- 🔴 Community statistics (POI, cities, participants)
- 🔴 FAQ / How it works
- 🔴 Footer: links, locales, PWA installation

**Bugs/Debts:**
- ⚠️ —

---

### 2.2 POI Map (map + list + modal)

**Routes:** `/pois` (index/new/create/update) — [`PoisController`](app/controllers/pois_controller.rb:12)

**Chain:** `PoisController` (index/view) → [`PoiReflex`](app/reflexes/poi_reflex.rb:16) (load_pois_in_bounds, load_more_pois, filter_by_categories, apply_filters, reset_filters, show_detail, show_detail_modal, edit_poi, create_comment, reverse_geocode, set_location, show_geolocation_toast) → [`PoiService`](app/services/poi_service.rb:12) → PostGIS (`within_bounds`/`within_meters`) → [`PoiBroadcaster`](app/broadcasters/poi_broadcaster.rb:12) / `ToastBroadcaster` → `UserChannel` / `AdminChannel`

**Components:** [`Poi::MapComponent`](app/components/poi/map_component.rb:1) (OpenLayers 10), `Poi::ListItemComponent`, `Poi::ShowComponent`, `Poi::FormComponent`, `Poi::FiltersComponent`, `Poi::CommentsComponent`, `Ui::SidebarComponent`. Modals: `Poi::DetailsComponent`, `Poi::GalleryComponent`, `Poi::RatingsComponent` (stubs).

**Status:** 🟡 Partial

**Done:**
- ✅ OpenLayers 10 map + clustering + PostGIS boundary queries
- ✅ Sidebar with a list of visible POIs + "Load more" (offset pagination)
- ✅ Filters by categories and search by JSONB name/description (Ransack + ILIKE)
- ✅ POI card in a modal (header + tabs)
- ✅ POI creation/edit form + mini map + reverse geocoding (Nominatim)
- ✅ Photo gallery via `PhotoService` (ActiveStorage)
- ✅ 100m proximity check for comments/editing (`check_proximity!`, `PoiCommentPolicy`)
- ✅ Live comments: `PoiCommentBroadcaster` + the `PoiComment` branch in `VersionObserverJob` (to the author); correct 100m proximity-check (Boolean + SRID 4326, anti-fraud no longer "always passes")
- ✅ TFT rewards for POI creation/comment (`GamificationService.award!(:poi_create/:comment_create)`, amounts from `config/gamification.yml`)
- ✅ Live map: `poi:reload-features` → re-query from the server; fallback marker loading in `map_component_controller.js` (retry `_loadPoisInBounds`)
- ✅ OSM import: the POIs tab updates incrementally (`inner_html [data-poi-category-pois]` every 10 imports), without `morph` card duplicates
- ✅ Reverse geocoding when opening the edit form (mini map in edit mode, autofill of address/city/country/zip)
- ✅ Coordinate validation: `handleSubmit` blocks submission without lat/lng (i18n `missing_coords`)
- ✅ The form mini-map reinitializes on `inner_html` (MutationObserver in `form_component_controller.js`)
- ✅ POI creation/editing from the map — via the `Poi::FormComponent` modal on the Reflex flow (`PoiReflex#create/#update` → `PoiService` → PaperTrail → `PoiBroadcaster`); without page reload, without JSON in the controller response; toast to the user via `ToastBroadcaster` (WebSocket); address autofill disabled (`autocomplete="off"`)
- ✅ Dynamic category fields in the POI form: `PoiReflex#load_category_fields` renders `Poi::FormFieldsComponent` by field_type (string/text/number/boolean/select/multiselect) into the `[data-poi-form-fields]` wrapper via CableReady (`inner_html`), namespace `poi[metadata][field_key]`
- ✅ Sidebar overlay: `Ui::SidebarComponent` expands OVER the map (absolute), without pushing the flex flow — map bounds are not recalculated (`poi:reload-features` is not duplicated, `_loadPoisInBounds` guard by `_lastBoundsKey`)

**Wishlist:**
- 🔴 `PoiRating` — 5-star system + aggregation into `poi.rating`
- 🔴 Comments: live for everyone + threaded replies
- 🔴 Gallery: grid + lightbox/slider
- 🔴 OSRM: route building to a POI + a line on the map
- 🔴 Offline mode (PWA): tiles + list (IndexedDB)

**Bugs/Debts:**
- ⚠️ Photo upload (binaries via StimulusReflex) → HTTP/multipart — a separate task
- ⚠️ POI card: UI polish (focus trap, aria, scroll locking) — a separate task
- ✅ Browser address autofill disabled: `autocomplete="off"` on address/city/country/zip_code in `Poi::FormComponent` and the admin `EditComponent`
- ⚠️ Admin. Edit form: layout + `Ui::DropdownComponent` instead of `<select>`; the mini map is not initialized; `rating` is a consolidated computed field, NOT manually editable. A user will show the page structure — a separate task.
- ⚠️ Filters. Component. Figure out. — a separate task.
---

### 2.3 User Profile (user profile)

**Route:** `/:slug` (show/edit) — [`UsersController`](app/controllers/users_controller.rb:13)

**Chain:** `UsersController` (show/edit, render) + [`UserReflex`](app/reflexes/user_reflex.rb:10) (update_profile) → [`UserService`](app/services/user_service.rb:15) (name + avatar via `PhotoService`) → [`UserBroadcaster`](app/broadcasters/user_broadcaster.rb:12) → `user_<id>` (inner_html by the `[data-user-profile-id]` wrapper)

**Components:** [`Users::ProfileComponent`](app/components/users/profile_component.rb:11), [`Users::FormComponent`](app/components/users/form_component.rb:1), `Users::RewardsComponent`, tabs `Ui::TabsComponent`.

**Status:** 🟡 Partial

**Done:**
- ✅ Profile display (avatar, name, email, status, TFT balance, badges, roles); the wallet is NOT shown to the user (only admin — Wallet tab)
- ✅ TFT crediting history in the profile: `Users::RewardsComponent` (live `inner_html [data-user-rewards]` via `TokenTransactionBroadcaster`)
- ✅ Name + avatar editing (via Broadcaster)
- ✅ Notification settings on `/:slug/settings` (see 2.4)
- ✅ Pundit: own profile or admin
- ✅ `User#badges` — badges by `badge_ids` via `gamification.yml` (the profile does not crash)
- ✅ Live name update via `UserBroadcaster`: rendering from a job fixes `I18n.with_locale(default)`, `cable_controller.js` applies CableReady operations one by one (per-op try/catch)
- ✅ `inactive` automation: `UserInactivityJob` (active without activity 6+ months → inactive) + `UserService.mark_inactive_old_users` + a record in `config/recurring.yml`

**Wishlist:**
- 🔴 Live tab switching (activity/audit) without reload
- 🔴 Gamification levels/badges section
- 🔴 Personal activity statistics (POI, comments, tokens)
- 🔴 Promo/discount code input field in the profile when purchasing paid features (Token Spend / premium): apply the discounted code before confirming payment

**Bugs/Debts:**
- ⚠️ Tabs (activity/audit) in the profile — switching is not live
- ⚠️ Unconfirmed verification → determine the behavior (reset/flag/retry)

---

### 2.4 User Settings (user settings)

**Route:** `/:slug/settings` — [`Users::SettingsController#show`](app/controllers/users/settings_controller.rb:10)

**Chain:** `SettingsReflex#update` ([`app/reflexes/settings_reflex.rb`](app/reflexes/settings_reflex.rb:5)) → [`SettingService.update`](app/services/setting_service.rb:3) → [`SettingBroadcaster`](app/broadcasters/setting_broadcaster.rb:11) → `user_<id>` (toast)

**Components:** [`Settings::FieldComponent`](app/components/settings/field_component.rb:1) (including the admin set via `admin/settings`)

**Status:** ✅ Done

**Done:**
- ✅ Event switches (in-app / email / push) for the user
- ✅ Autosave via Reflex + toast (toasts only via broadcast, without local renders)

**Wishlist:**
- 🔴 Email/push verification before enabling channels
- 🔴 Grouping and search by events

**Bugs/Debts:**
- ⚠️ —

---

### 2.5 Auth pages (authentication)

**Routes:** Devise `/users/*` (sessions/registrations/confirmations/passwords/unlocks) + Google OAuth (`/users/auth/google_oauth2`) — [`config/routes.rb`](config/routes.rb:19)

**Chain:** Devise controllers (`users/*`) → `UserService.handle_google_oauth` ([`app/services/user_service.rb`](app/services/user_service.rb:34)) → `Setting.create_for_user` + `WalletService.create_hidden_wallet` (OAuth immediately) + welcome tokens (`award_registration_bonus!`)

**Status:** ✅ Done

**Done:**
- ✅ Registration/login/confirmation/password recovery (Devise + confirmable + lockable)
- ✅ **Registration does NOT authorize before confirmation:** redirect to the login page with the flash "confirm your email" (`after_inactive_sign_up_path_for` → `new_user_session_path`, `signed_up_but_unconfirmed`)
- ✅ Google OAuth (OmniAuth) + avatar via `PhotoService`
- ✅ Default roles (:user), referral code at registration
- ✅ **A hidden custodial wallet is created IMMEDIATELY at registration** (both email and OAuth): welcome credits immediately get an on-chain address → relay sends instantly
- ✅ Welcome TFT tokens (10) at registration + referral bonuses (15/5) via `award_registration_bonus!` — **instantly, without a lock period** (off-chain ledger)
- ✅ Referral relation `users.referred_by_id` (self-join) + `TokenTransaction` transaction journal — when registering with a refcode, both are credited (15/5), the referrer/referees are visible in the admin
- ✅ Status changes / email confirmation / soft-delete — confirmed by `user_lifecycle_spec` (0 failures)

**Wishlist:**
- 🔴 EIP-2771: sponsored transactions (on-chain sending via the server already exists, see 4.2)
- 🔴 Registration via an OAuth controller with a referral code: the OAuth flow lacks UI for entering/passing the refcode (`?ref=` on the authorize button / field). The backend code acceptance works — `User.from_google_oauth(auth, referral_code_input)` + `UserService.handle_google_oauth` (see §4.2), only the UI part is required.

**Bugs/Debts:**
- ⚠️ —

---

## 3. 🛠 ADMIN SECTION (`/admin-panel`)

> Layout [`app/views/layouts/admin.html.erb`](app/views/layouts/admin.html.erb:43): Navbar + Sidebar + content + toasts. Channel: `AdminChannel` (admin/moderator). Base: [`Admin::BaseController`](app/controllers/admin/base_controller.rb:11).

### 3.1 Dashboard

**Route:** `/admin-panel` — [`Admin::DashboardController#index`](app/controllers/admin/dashboard_controller.rb:9)

**Chain:** `Admin::DashboardReflex` (refresh/refresh_stats) + `Admin::DashboardService.stats` → [`Admin::DashboardBroadcaster`](app/broadcasters/admin/dashboard_broadcaster.rb:3) (`inner_html [data-admin-*]`) → `AdminChannel`

**Components:** [`Admin::DashboardComponent`](app/components/admin/dashboard_component.rb:15), `Admin::Dashboard::StatCardComponent`, `Ui::BreadcrumbsComponent`

**Status:** ✅ Done

**Done:**
- ✅ Statistics cards (total/active/suspended/pending + new_users_today) with live updates
- ✅ `Admin::DashboardService.stats` returns `total_users/active_users/suspended_users/new_users_today` (matches `DashboardComponent`); `new_users_today` = registered today (not pending)
- ✅ Recent users + recent activities (from `versions`)
- ✅ Authorization: admin/moderator

**Wishlist:**
- 🔴 Charts: Chartkick/Groupdate (activity, geo, categories, views)
- 🔴 GA/GTM integration
- 🔴 POI KPIs (pending/approved/rejected), OSM imports, comments

**Bugs/Debts:**
- ⚠️ admin_channel.js: skip morph (selector not found): `[data-admin-stats-total-users]` — the selector is sent when the admin is on another page (harmless warning, worth silencing)

---

### 3.2 Users

**Routes:** `/admin-panel/users` (index/show/update) — [`Admin::UsersController`](app/controllers/admin/users_controller.rb:12)

**Chain:** [`Admin::UsersReflex`](app/reflexes/admin/users_reflex.rb:11) (update/destroy/filter/sort/reset_filters) → [`Admin::UserService`](app/services/admin/user_service.rb:19) → [`Admin::UserBroadcaster`](app/broadcasters/admin/user_broadcaster.rb:15) (inner_html of the `[data-admin-users-list]` table, prepend, remove, audit, dispatch_event) → `AdminChannel`

**Components:** `Admin::Users::TableComponent`, `Admin::Users::RowComponent`, `Admin::Users::User::ShowComponent`, `EditComponent`, `ActivityComponent`, `WalletComponent`, `AuditLogComponent` (`Ui::AuditEntryComponent`), `Ui::FiltersComponent`, `Ui::TabsComponent`

**Status:** ✅ Done (CRUD + live)

**Done:**
- ✅ List + search + filter by status (including deleted) + sorting + pagination (pagy)
- ✅ Detail page: profile + tabs (Activity / Wallet / Audit Log)
- ✅ Wallet tab: TFT balance + transaction history (`TokenTransaction`) + explorer link (4+4 excerpt) + referral info (referrer/referee count); live `inner_html [data-admin-user-wallet]`
- ✅ Editing (name/email/status/role) + soft delete (status `deleted`, the record is not removed)
- ✅ Live: prepend of a new user + table update (inner_html) via `AdminChannel`; deleted is hidden in "All", visible through the status filter
- ✅ Role management: the form sends `role_id` (one role), permit `role_id` ↔ `Admin::UserService#update_user_roles!`
- ✅ Google OAuth avatar: `Ui::AvatarComponent#avatar_url` with fallback to the blob URL + rescue (representation failure in the worker)

**Wishlist:**
- 🔴 Bulk operations (batch status, batch role)
- 🔴 List export (CSV)

**Bugs/Debts:**
- ⚠️ —

---

### 3.3 PoiCategories + fields + OSM import

**Routes:** `/admin-panel/poi_categories` (index/show/new/create/update) — [`Admin::PoiCategoriesController`](app/controllers/admin/poi_categories_controller.rb:11)

**Chain:** [`Admin::PoiCategoriesReflex`](app/reflexes/admin/poi_categories_reflex.rb:10) (create/update/filter/import_from_osm/pois_page/audit_page) + [`Admin::PoiCategoryFieldsReflex`](app/reflexes/admin/poi_category_fields_reflex.rb:9) (create/update/destroy/reorder) → [`PoiCategoryService`](app/services/poi_category_service.rb:11) + [`OSMImportService`](app/services/osm_import_service.rb:1) → [`PoiCategoryBroadcaster`](app/broadcasters/poi_category_broadcaster.rb:18) / [`OsmImportBroadcaster`](app/broadcasters/osm_import_broadcaster.rb:11) → `AdminChannel` / `user_<id>`

**Components:** `Admin::PoiCategories::TableComponent`, `RowComponent`, `Admin::PoiCategories::PoiCategory::ShowComponent`, `EditComponent`, `FieldsListComponent`, `FieldFormComponent`, `PoisListComponent`, `AuditLogComponent`, `OSMImportComponent`, `Ui::AuditEntryComponent`

**Status:** ✅ Done (section reference)

**Done:**
- ✅ Category CRUD (JSONB name/description in 4 locales, slug, icon, position, active)
- ✅ Dynamic category fields (create/update/delete/reorder via `update!` for audit)
- ✅ Reverse geocoding in the POI form (Nominatim)
- ✅ OSM import: fetch + process with progress (`OsmImportBroadcaster.progress`)
- ✅ Unified category + fields audit feed (including deleted via `parse_version_object`)
- ✅ **Live POIs tab:** after import `OsmImportBroadcaster` calls `PoiCategoryBroadcaster` → `inner_html [data-poi-category-pois]` (new POIs appear without reload)
- ✅ **Live map:** the `poi:reload-features` event → `_loadPoisInBounds()` (re-query from the server)
- ✅ **Notifications by settings:** unified `PoiCategoryNotification` (multicast initiator + admins), personal Setting filters (in-app/email/push); `osm_import_*` columns in `settings`

**Wishlist:**
- 🔴 DAO category verification
- 🔴 Background OSM import via SolidQueue (currently synchronous in the Reflex)

**Bugs/Debts:**
- ⚠️ "Audit log" tab: admin_channel.js does not find the `[data-audit-log]` selector (skip morph) — check the audit zone render

---

### 3.4 Pois (points of interest)

**Routes:** `/admin-panel/pois` (index/show/new/create/update) — [`Admin::PoisController`](app/controllers/admin/pois_controller.rb:11)

**Chain:** [`Admin::PoisReflex`](app/reflexes/admin/pois_reflex.rb:11) (update/create/change_status/destroy/filter/sort/reset_filters) → [`PoiService`](app/services/poi_service.rb:12) → [`PoiBroadcaster`](app/broadcasters/poi_broadcaster.rb:12) → `AdminChannel` / `UserChannel`

**Components:** `Admin::Pois::TableComponent`, `RowComponent`, `Admin::Pois::Poi::ShowComponent`, `EditComponent`, `Ui::FiltersComponent`, `Ui::TabsComponent`, `Poi::MapComponent`

**Status:** 🟡 Partial

**Done:**
- ✅ List + search + filters (status/category) + sorting + pagination
- ✅ Detail page: Details / Map / Audit Log
- ✅ Status moderation (pending/approved/rejected/archived)
- ✅ Multilingual JSONB name/description + dynamic fields in metadata
- ✅ `Admin::PoisReflex#update`/`change_status` — `morph :nothing` + toast; the `#poi-detail` zone is rendered by `PoiBroadcaster` (live for ALL admins)
- ✅ Mini map on editing: `form_component_controller.js` initializes the map via MutationObserver (the CableReady operation order does not "hang")
- ✅ Badges `first_poi`/`contributor` (relation `User#pois`)
- ✅ After creating a POI via the admin, the point appears on the map (`poi:reload-features` + fallback marker loading)

**Wishlist:**
- 🔴 POI card by the unified pattern: tabs Details/Comments/Ratings/Gallery/Audit
- 🔴 Bulk moderation

**Bugs/Debts:**
- ⚠️ Gallery: viewing `Poi#photos` (grid + lightbox) is not implemented

---

### 3.5 Settings (admin notification settings)

**Route:** `/admin-panel/settings` (resource :settings, only: show) — [`Admin::SettingsController`](app/controllers/admin/settings_controller.rb:1)

**Chain:** `SettingsReflex#update` → `SettingService.update` → `SettingBroadcaster` → `user_<id>` (admin as a regular user)

**Components:** [`Settings::FieldComponent`](app/components/settings/field_component.rb:1), `Ui::AuditEntryComponent`, `Ui::BreadcrumbsComponent`

**Status:** ✅ Done

**Done:**
- ✅ All event types (including admin ones: new_registration, user_updated_by_admin, etc.)
- ✅ Autosave + toast + Settings audit feed

**Wishlist:**
- 🔴 Separation of admin event notifications by roles (Rolify filtering)

**Bugs/Debts:**
- ⚠️ —

---

### 3.6 Contract Mgmt (contract management)

**Status:** 🔴 Planned (see layer 4.2)

**Wishlist:**
- 🔴 Mint/rate/pause/rewards via the admin
- 🔴 `ContractSnapshot` (contract monitoring): model `contract_type`/`data jsonb`/`created_at` with rotation (no monitoring code yet)

**Bugs/Debts:**
- ⚠️ —

---

## 4. Horizontal layers (cross-cutting)

### 4.1 Auth & Roles
**Status:** ✅ Done
- ✅ Devise (email + confirmable + lockable), Google OAuth (OmniAuth), Bcrypt
- ✅ Pundit policies: `UserPolicy`, `PoiPolicy`, `PoiCommentPolicy`, `PoiCategoryPolicy`, `SettingPolicy`, `Admin::UserPolicy`, `Admin::DashboardPolicy`, `AdminPolicy`
- ✅ Rolify: roles `admin` / `moderator` / `user`; `AdminChannel` — admin/moderator
- ✅ **User statuses (clean model):** `pending` (registered, email not confirmed) → `active` (after confirmation) → `inactive` (inactivity 6+ months, automation — `UserInactivityJob` recurring); `suspended`/`banned` (admin), `deleted` (soft delete — the record is not removed, protection against repeated registration; visible to the admin through the status filter). We never physically delete users.

### 4.2 Gamification & Web3
**Status:** 🟡 Token model ✅ / 🔴 EIP-2771
- ✅ **TOKEN MODEL:** rewards are TFT tokens (`UserReward`, off-chain ledger), `User#token_balance`; `GamificationService` (`award!`, `award_referral!`, `badge_key`, `check_badges!`); badges — `gamifications` (event_type badge); welcome 10 / referral 5+5 TFT (referrer — vesting, newcomer — instantly). **Levels are a planned metric from `token_balance`** (see the wishlist below).
- ✅ **`TokenTransaction` transaction journal:** each reward → a credit record (amount/action_key/tx_hash/status/chain_id/wallet_id/user_reward_id) in a single transaction with `UserReward`; `tx_hash` is filled after the on-chain send, in the admin — an explorer link with a 4+4 excerpt; the balance remains instant (off-chain, without a lock period)
- ✅ **On-chain relay (server-side sending):** `TokenTransactionService.relay!` + `TokenTransactionRelayJob` (SolidQueue) — EIP-155 signature (RLP/ECDSA in [`Crypto::Ethereum`](lib/crypto/ethereum.rb:1)) with the operator's private key (`OPERATOR_PRIVATE_KEY`, `.env`) → `eth_sendRawTransaction` → `transfer(address,uint256)` to the **reward pool contract** (`REWARDS_CONTRACT_ADDRESS`) — tokens are taken from the pool balance (NOT mint), gas is sponsored by the operator (gasless for the user). **`relay!` is resistant to any exceptions (including `Exception` — WebMock in tests): marks `failed`, the job does not drop the worker.**
- ✅ **Relay serialization by operator:** `limits_concurrency key: "token-relay-operator", to: 1, on_conflict: :block` — all credits are signed with one key, sending is strictly sequential (no nonce conflicts during parallel relay).
- ✅ **Auto-retry of failed relays:** `TokenTransactionRetryJob` (recurring every 15 min) finds `status: failed` + `tx_hash: nil` and resends via `relay!` only the instant/available-by-lock-period ones (vesting, not yet unlocked, — wait for claim).
- ✅ **Crediting point = active status:** welcome tokens and referral bonuses are credited ONLY to an active account. Email — after confirmation (`ConfirmationsController#show`, the wallet is created before crediting); OAuth — immediately (the user is active). The referral relation (`referred_by`) is fixed at registration (`UserService.save_referral!`) — survives confirmation.
- ⚠️ **OAuth refcode:** the backend accepts the refcode — `User.from_google_oauth(auth, referral_code_input)` passes `?ref=`/`session[:referral_code]` into `UserService.handle_google_oauth` (ref credits work when the code is passed). But the OAuth flow has NO UI for entering the refcode and the authorize button does not form `?ref=` → a full referral scenario via OAuth is unavailable until the UI part is implemented (see wishlist §2.4).
- ✅ **Pool config + monitoring:** the `pool` section in `config/gamification.yml` (`lock_days`, `warning_balance`, `critical_balance`); `ContractBalanceCheckJob` (SolidQueue recurring) reads the pool balance via `TokenTransactionService.balance_of` and sends admins `ContractBalanceNotification` (Noticed) when the balance is low (yellow/red banner in the interface — later, with components).
- ✅ **ECDSA signature on Ruby 3.4:** [`Crypto::Ethereum#ecdsa_sign`](lib/crypto/ethereum.rb:231) — point coordinates are extracted via `to_octet_string(:uncompressed)` (the `OpenSSL::PKey::EC::Point` API has no `#x/#y`); `sign_transaction` is covered by a test
- ✅ **Dev check (Base Sepolia):** run `bin/jobs` → register a user → the relay job will send a mint → the transaction in the explorer, in the admin an explorer link (4+4 excerpt); `balanceOf(custodial)` == off-chain `token_balance`. RSpec RPC is **mocked** (WebMock) — the real network is not touched in tests
- ✅ **Custodial wallet:** the `Wallet` model (`kind: custodial/external`), `WalletService.create_hidden_wallet` (EIP-55, private key encryption `MessageEncryptor`), generation in Ruby without new gems ([`Crypto::Ethereum`](lib/crypto/ethereum.rb:1) — OpenSSL secp256k1 + keccak256 + EIP-55). Email — after confirmation, OAuth — immediately.
- ✅ ERC-20 TFT contracts (`travel-fi.sol`) — **written, deployed, and verified in the testnet** (network details — in `.env`); on-chain sending via `TokenTransactionService.relay!` ([`token_transaction_service.rb`](app/services/token_transaction_service.rb:22))
- 🔴 EIP-2771 forwarder + admin hot-wallet; Jetton TON + bridge
- 🔴 Token Spend (premium features), Contract Mgmt in the admin
- 🔴 **Levels from `token_balance`**: how much TFT the user accumulated → a level (reputation/progression in the profile); thresholds — a product task
- ⚠️ **ETH/USDT and TON/USDT rate:** develop a method in the transaction service to get the current rate and call it before each conversion. The token is fixed (1 TFT = 1 USDT) — the rate is needed to understand the real market situation and set the exchange rate.
- ✅ **Lock-blocking of credits (referrer anti-fraud):** `referral_bonus_referrer` is excluded from `INSTANT_ACTION_KEYS` — the referrer follows the vesting lock period (`updated_at + lock_days`), the received marker is a boolean `claimed`. The newcomer bonus and welcome — instantly (lock=0).
- 🔴 **Target on-chain crediting scheme (two-stage off-chain → on-chain, locking in the DB):**
  - **Stage 1 (off-chain, immediately, via Service→Job):** action → `UserReward` + `TokenTransaction` in a single transaction. Balance/badges/levels update immediately — locked TFT are virtual (internal DB account), the on-chain `relay` goes to the queue only at the moment of unlock/claim.
  - **Stage 2 (on-chain, by the "Claim rewards" button or an auto-claim job):** one relay send via Service→Job (SolidQueue) → real TFT to the custodial wallet. Gas is paid once per claim.
  - **The lock period is a computable check, there is NO field:** a `TokenTransaction` record is unlocked if `updated_at + lock_days(config)` has already arrived. The "received" marker is a **boolean field** (`claimed`), set on a successful relay; meanwhile `updated_at` updates (PaperTrail audit triggers → broadcast).
  -   **Registration/newcomer bonus:** relay **immediately** (lock=0) — to the wallet, without a lock. **The REFERRER's referral bonus** — by the lock period (vesting, anti-fraud of fake registrations).
  - **`sendRewardBatch` — ONLY for promotions/bulk rewards** (several users in one tx), not as a regular process.
  - **Banner "available Y to withdraw / Z on balance":** backend calculation from `TokenTransaction` scopes — `available` (unlocked by `updated_at` AND `claimed == false`), `locked` (the lock period has not passed yet). No manual counter needed.
  - **Claim flow:** button → Service (`UserService.claim_rewards!`) → collects `available` credits → queues the relay Job → on success `claimed = true` (and `updated_at` updates → audit → broadcast).
- 🔴 **Move all dynamic gamification settings from `config/gamification.yml` into the `Setting` entity + UI in the admin `/admin-panel/settings`:** not only the pool (`rewards_lock_days`, `pool_warning_balance`, `pool_critical_balance`), but also reward amounts (registration 10, referral 15+5, poi_create/photo/comment/vote) and badge thresholds (first_poi, contributor, explorer, recruiter, veteran, …). `GamificationService` reads from `Setting` (fallback to YAML defaults before the first save); a form (numeric inputs/thresholds) via the `SettingsReflex#update` → `SettingService.update` → `SettingBroadcaster` pipeline; PaperTrail audit; on-chain lock synchronization via `setLockDays`. **While the settings remain in YAML — the full migration later as a separate task.**
- 🔴 **TFT reward for reaching a level (rating system):** when crossing the `token_balance` threshold (level from config) → a one-time reward by the two-stage §4.2 scheme (new `action_key`, e.g. `level_up`). Implemented together with the rating system.
- 🔴 **Promotions / bulk rewards via `sendRewardBatch`:** one-off campaigns awarding a group of users in one tx (promotions, giveaways, community bonuses). A separate feature on top of the two-stage scheme.

### 4.3 Realtime infrastructure
**Status:** ✅ Done
- ✅ StimulusReflex + CableReady + SolidCable (database-backed ActionCable), channels `AdminChannel`/`UserChannel`
- ✅ SolidQueue + SolidQueueDashboard (mount `/solid-queue`), SolidCache (infrastructure; cache disabled in code)

### 4.4 Audit (PaperTrail)
**Status:** ✅ Done
- ✅ PaperTrail (Single Source of Truth) → [`VersionObserverJob`](app/jobs/version_observer_job.rb:12) (branches `handle_<model>_update`) → Broadcasters
- ✅ [`PaperTrailAuditService`](app/services/paper_trail_audit_service.rb:1), `UserAuditLogger`, `UserActivityService`
- ✅ Rule: `update!`/`save!` (versions → broadcast), `update_all` is forbidden for audited data

### 4.5 Notifications (Noticed)
**Status:** 🟡 Partial (in-app/database ✅; email — debt)
- ✅ In-app (action_cable) and database notifications work (including `PoiCategoryNotification`)
- ✅ Channel filtering via `Setting` (`setting_field_enabled?`), Web push [`web_push.rb`](app/notifications/noticed/delivery_methods/web_push.rb:1)
- ✅ **Noticed 3.0.0:** `ApplicationNotification < Noticed::Event`, `required_param`, without `deliver_by :database` (records are saved automatically), `WebPush < Noticed::DeliveryMethod`. `action_cable` (UserChannel) is configured.
- ✅ Email delivery verified: `UserMailer.profile_updated` with `params[:recipient]`; the `email_enabled?` Setting filter — covered by the test `spec/notifications/user_profile_notification_spec.rb`

### 4.6 i18n / UI (ViewComponents)
**Status:** ✅ Done
- ✅ 4 locales (en/ru/es/zh); sidecar ViewComponents (rb + html + css + controller.js + 4 yml)
- ✅ Only the green-blue Tailwind palette (emerald/teal/sky), MDI icons, partials forbidden
- ✅ UI library: `Ui::CardComponent`, `BtnComponent`, `DropdownComponent`, `TabsComponent`, `BadgeComponent`, `AvatarComponent`, `TooltipComponent`, `BreadcrumbsComponent`, `PaginationComponent`, `ConfirmDialogComponent`, `ToastComponent`, `SidebarComponent`, `NavbarComponent`, `FiltersComponent`, `AuditEntryComponent`, `ClipboardComponent`, `DateComponent`, `HamburgerComponent`

### 4.7 PWA / Devices
**Status:** 🟡 Partial
- ✅ Manifest + service worker ([`app/views/pwa/`](app/views/pwa/manifest.json.erb:1))
- 🟡 App installation icons (logo/background) — exist, need refinement
- 🔴 Offline: map tiles, offline list (IndexedDB), offline GPX/CSV, push

### 4.8 CI / Tests / Production
**Status:** 🟡
- ✅ CI: brakeman/bundler-audit/rubocop/yarn audit — exists; **rspec added to [`config/ci.rb`](config/ci.rb:1)**
- ✅ **Full RSpec suite green:** `CUPRITE_HEADLESS=true bundle exec rspec` → **250 examples, 0 failures, 3 pending** (stubs: PoiRating, live comments for everyone). Run ~2.5 min
- ✅ **Run stability:** streaming indication `[START] <example>` with `$stdout.flush` in [`spec/rails_helper.rb`](spec/rails_helper.rb:38) — the current example is visible on a hang; ENV mocks with `and_call_original` — cascade failure of `DatabaseCleaner` (dirty DB → false failures of `User scopes`/`DashboardService.stats`) is fixed
- 🔴 Production deploy: [`config/deploy.yml`](config/deploy.yml:1) — stubs `192.168.0.1`/`localhost:5555`; domain, SMTP, force_ssl
- 🟡 Performance: tile caching, PostGIS optimization, SolidCable clustering, GeoJSON cache

---

## 5. Entity relations + data flows

### 5.1 Entity relations (table)

| # | Model | Relation | Model | Description |
|---|--------|-------|--------|----------|
| 1 | `User` | 1 — 1 | `Setting` | each user has one notification settings row |
| 2 | `User` | 1 — N | `Gamification` | user badges (event_type badge) |
| 3 | `User` | M — N | `Role` | roles via the `users_roles` table (Rolify) |
| 4 | `User` | 1 — N | `Poi` | user — creator of points |
| 5 | `User` | 1 — N | `PoiComment` | user — author of comments |
| 6 | `User` | 1 — N | `Wallet` | custodial (ours) / external (own) wallets |
| 7 | `User` | 1 — N | `UserReward` | off-chain TFT token credits |
| 8 | `User` | 1 — N | `TokenTransaction` | token movement journal (credit/debit) |
| 9 | `User` | 1 — 1 | `User` (referred_by) | self-join: who invited (refcode) |
| 10 | `PoiCategory` | 1 — N | `PoiCategoryField` | the category defines the set of dynamic fields |
| 11 | `PoiCategory` | 1 — N | `Poi` | the category contains points |
| 12 | `Poi` | 1 — N | `PoiComment` | comments to a point (self-join `parent_id` — replies) |
| 13 | `Poi` | 1 — N | `Photo` | photo gallery (ActiveStorage) |
| 14 | `Poi` | 1 — N | `PoiRating` | 5-star ratings (🔴 planned) |
| 15 | *(all)* | — | `PaperTrail::Version` | audit of changes of all models with `has_paper_trail` |

### 5.2 Reference update chain (Database-Triggered Workflow)

```
Browser (Stimulus: click/input)
   │  this.stimulate("XxxReflex#action", params) — RPC over WebSocket
   ▼
Reflex (morph :nothing, deep_symbolize_keys, authorize_with_pundit!)
   │  only delegates to the Service
   ▼
Service (Pundit + Model.save!/update! inside a transaction)
   ▼
PostgreSQL + PaperTrail → a Version record
   ▼
VersionObserverJob (SolidQueue) — branch handle_<model>_update
   ▼
Broadcaster (helpers.render + cable_ready.inner_html by wrapper selectors)
   ▼
CableReady + ActionCable (SolidCable) → stream user_N / AdminChannel
   ▼
The DOM updates selectively in all subscribed browsers
```

### 5.3 Data flows between sections

- **User Profile ↔ Admin Users:** user change → PaperTrail → `VersionObserverJob#handle_user_update` → `Admin::UserBroadcaster` (AdminChannel) + `UserBroadcaster` (user_N) + `UserProfileNotification` (Noticed, filter by `Setting`).
- **POI Map ↔ Admin Pois:** POI creation/change → `VersionObserverJob#handle_poi_update` → `PoiBroadcaster` (list + toast + `poi:reload-features` → map) + `Admin::DashboardBroadcaster.broadcast_stats_update`.
- **PoiCategories ↔ POI Map:** category/field change → `PoiCategoryBroadcaster` (AdminChannel, card/fields/POI/audit); POI visibility on the map depends on `poi_categories.active` (scope `Poi.visible`).
- **OSM import ↔ POI Map:** `Admin::PoiCategoriesReflex#import_from_osm` → `OsmImportBroadcaster` (progress/result in user_N) + `poi:reload-features` → reload of map markers.
- **Settings ↔ Notifications:** `SettingsReflex` → `SettingService` → `SettingBroadcaster` (user_N); `Setting` filters are applied when sending Noticed.
- **Gamification ↔ Wallet/TokenTransaction:** `GamificationService.award!` → `UserReward` + `TokenTransaction` (in one transaction) → `TokenTransactionRelayJob` (SolidQueue) → on-chain mint.

---

## 6. 🧪 TESTS

### Principle (reference)
One test per scenario = **"browser A → browser B"**: A performs an action (Reflex/Service → save! → PaperTrail → VersionObserverJob → Broadcaster → CableReady) → B sees a live update WITHOUT reload + notifications by its own settings.

### Infrastructure
- ✅ RSpec + FactoryBot + PostGIS; **Capybara + Selenium Chrome**: headful window locally, headless (`--headless=new`) in CI (`CUPRITE_HEADLESS=true`/`ENV['CI']`)
- ✅ DatabaseCleaner (system — truncation, the rest — transaction); WebMock (Overpass/RPC mock); ActiveJob `:test`
- ✅ ActionCable in tests — `solid_cable` (live between browsers), test cable DB `travel_fi_test_cable`
- ✅ Helpers [`spec/support/system_helpers.rb`](spec/support/system_helpers.rb:1): `browser_a`/`browser_b`, `sign_in_via_ui`, `wait_for_selector`, `perform_enqueued_jobs_now`
- ✅ Streaming indication `[START] <example>` in [`spec/rails_helper.rb`](spec/rails_helper.rb:38) — the current example is visible on a hang

### End-to-end system tests (created) — structure by sections/entities
```
spec/system/
├── user/                       # 👤 USER SECTION (2.x)
│   ├── poi_map_spec.rb         # 2.2 POI Map (Poi) ✅
│   ├── user_lifecycle_spec.rb  # 2.3/2.5/3.2 User (reference) ✅
│   ├── user_auth_spec.rb       # 2.5 Auth ✅
│   └── user_settings_spec.rb   # 2.4 User Settings ✅
├── admin/                      # 🛠 ADMIN SECTION (3.x)
│   ├── users_spec.rb           # 3.2 Admin Users ✅
│   ├── poi_category_spec.rb    # 3.3 PoiCategories ✅
│   └── pois_spec.rb            # 3.4 Admin Pois ✅
└── layer/                      # horizontal layers (4.x)
    ├── gamification_spec.rb    # 4.2 Gamification ✅
    └── referral_rewards_spec.rb# 4.2 Referral credits ✅
```
- ✅ **`User`** (reference, [`user_lifecycle_spec.rb`](spec/system/user/user_lifecycle_spec.rb:1)) — registration → confirmation → wallet → welcome tokens → admin live (status/name) → profile (balance/wallet hidden) → soft delete → audit → notifications
- ✅ **`Admin::PoiCategory`** (reference, [`poi_category_spec.rb`](spec/system/admin/poi_category_spec.rb:1))
- ✅ `Admin::User` ([`users_spec.rb`](spec/system/admin/users_spec.rb:1)) — status change (browser A → B)
- ✅ `Auth` ([`user_auth_spec.rb`](spec/system/user/user_auth_spec.rb:1)) — registration → visibility to admin B
- ✅ `Gamification` ([`gamification_spec.rb`](spec/system/layer/gamification_spec.rb:1)) — tokens → balance + history in the profile
- ✅ `Referral rewards` ([`referral_rewards_spec.rb`](spec/system/layer/referral_rewards_spec.rb:1)) — registration with a refcode → credits to both (15/5), balance+history, Wallet at the admin (explorer link 4+4)
- ✅ `TokenTransactionService` ([`token_transaction_service_spec.rb`](spec/services/token_transaction_service_spec.rb:1)) — relay mint (WebMock RPC) + `to_wei`; `TokenTransactionRelayJob` ([`token_transaction_relay_job_spec.rb`](spec/jobs/token_transaction_relay_job_spec.rb:1)); signature/RLP — [`ethereum_spec.rb`](spec/lib/crypto/ethereum_spec.rb:39)
- ✅ `User::Settings` ([`user_settings_spec.rb`](spec/system/user/user_settings_spec.rb:1))
- ✅ `Admin::Poi` ([`pois_spec.rb`](spec/system/admin/pois_spec.rb:1)) — POI creation → visible in the admin list
- ✅ `POI Map` ([`poi_map_spec.rb`](spec/system/user/poi_map_spec.rb:1)) — live map (Selenium headful/headless + CDP geolocation)

### Recent runs journal
- ✅ **Full suite (07.08.2026)** — **250 examples, 0 failures, 3 pending** (stubs `PoiRating`×2 + `PoiComment` live). Closed bugs: (1) `relay!` dropped the job — `WebMock::NetConnectNotAllowedError < Exception` was not caught by `rescue StandardError`, added `Exception` catch + `mark_failed`; (2) ECDSA signature failed on Ruby 3.4 — `OpenSSL::PKey::EC::Point` coordinates via `to_octet_string(:uncompressed)`; (3) ENV mocks broke `DatabaseCleaner` (cascade: dirty DB → false failures of `User scopes`/`DashboardService.stats`) — added `and_call_original`; (4) removed the `already initialized constant` warning (duplication of `TOKEN_ADDRESS`/`RPC_URL` constants).
- ✅ **Full suite (06.08.2026)** — **173 examples, 0 failures, 3 pending**. Test infrastructure: Selenium Chrome (headful/headless), precompiled assets, `wait_for_selector` → `has_css?(visible: false)`, rspec in `config/ci.rb`. Closed bugs: `Admin::PoisReflex#update` morph→Broadcaster; `Admin::DashboardService.stats` keys; `Admin::DashboardBroadcaster` morph→inner_html; POI not on the map — fallback loading; per-entry rescue of audit zones.
- ✅ **POI full coverage (06.08.2026)** — **unit+reflex+controller+broadcaster: 81 examples, 0 failures, 2 pending**. Closed bugs: SRID 4326; JSONB search; `nearby`; `PoiPolicy::Scope` for a guest; TFT rewards; `first_poi`/`contributor` badges; live comments; `filter_by_categories` NameError; `PoiBroadcaster` morph→inner_html; `Poi::AddFormComponent`; `PolicyScopingNotPerformedError`.
- ✅ **User + PoiCategory entities (05.08.2026)** — **16 examples, 0 failures**: unit (`UserService`/`Admin::DashboardService`/`OsmImportService`/`UserInactivityJob`) + system (`user_lifecycle`/`poi_category`/`admin_users`/`auth`/`gamification`/`settings`)
- ✅ `poi_category_spec` (05.08.2026) — **1 example, 0 failures** — after the OSM import fix (incremental `inner_html [data-poi-category-pois]`)
- ✅ `auth_spec` + `user_lifecycle_spec` (05.08.2026) — **2 examples, 0 failures** — repeated confirmation of `User`/`Auth`
- ✅ Noticed 3.x deprecations removed by migration (`Noticed::Event`, `required_param`, without `deliver_by :database`)

### Not done → fix, then test
- ⚠️ `PoiComment` live for everyone (currently only the author) — bug
- ⚠️ Photo upload (binaries via Reflex) — bug

### Backlog links
- 🔴 The broadcast pipeline actually delivers (SolidQueue worker, cable DB, client subscription)
- 🔴 `update_all` is not used for audited data (only `update!`/`save!`)
