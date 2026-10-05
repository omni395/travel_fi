# Travel Fi — Product Roadmap

> Living product status by **application section**: what works, what is in progress, what is planned.
> **Statuses:** `✅` works · `🟡` partial · `🔴` planned · `⚠️` bug/debt
> **Grant estimate (what to build + time + cost)** — in [`MILESTONES.md`](MILESTONES.md). **Debts register** — in [`TECH-DEBTS.md`](TECH-DEBTS.md). AI-agent instructions — in `.roo/rules/*`. Architecture — in [`README.md`](README.md).

---

## 1. Application sections map

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
│   └── 3.8 Contracts        🔴 (planned)
├── 4. Horizontal layers
│   ├── 4.1 Auth & Roles     ✅
│   ├── 4.2 Gamification & Web3  🟡
│   ├── 4.3 Realtime infra   ✅
│   ├── 4.4 Audit            ✅
│   ├── 4.5 Notifications    🟡
│   ├── 4.6 i18n / UI        ✅
│   ├── 4.7 PWA / Devices    🟡
│   └── 4.8 CI / Tests / Production  🟡
└── 5. Relations + data flows
```

---

## 2. 👤 USER SECTION

### 2.1 Landing (home)
**Status:** 🔴 stub — [`app/views/pages/index.html.erb`](app/views/pages/index.html.erb:1) holds test content. Route + redirect of a logged-in user to the map work.
**Wishlist:** full landing (hero, popular categories, community stats, FAQ, footer).

### 2.2 POI Map (map + list + modal)
**Status:** 🟡 partial — core works (OpenLayers 10 + clustering, PostGIS filters, POI modal with tabs, photo gallery, threaded comments live, OSM import incl. `.pbf`, dynamic category fields, TFT rewards, map-live updates).
**Planned / debts (details → [`MILESTONES.md`](MILESTONES.md) M1/M3):** Suggested Edits + 100m consensus, Quick Toggles, «Report an error», live tabs, OSRM route, PWA offline. `PoiComment` live for everyone (currently author-only). Filters component — figure it out.

### 2.3 User Profile (user profile)
**Status:** 🟡 partial — profile display, TFT rewards history, TFT Balance block (available/locked + claim), name/avatar edit, Pundit, `inactive` automation.
**Planned / debts:** live tab switching (activity/audit); unconfirmed verification behavior; gamification levels/badges section (contribution-based).

### 2.4 User Settings (user settings)
**Status:** ✅ done

### 2.5 Auth pages (authentication)
**Status:** ✅ done — Devise + confirmable + lockable, Google OAuth (+referral code backend), hidden custodial wallet created at registration, welcome/referral TFT.

---

## 3. 🛠 ADMIN SECTION (`/admin-panel`)

### 3.1 Dashboard
**Status:** ✅ done — stat cards, recent users/activities (from `versions`), auth admin/moderator.
**Planned:** charts (Chartkick/Groupdate).

### 3.2 Users
**Status:** ✅ done — list/search/filter/sort/pagination, detail tabs, wallet tab, edit + soft delete, live updates.
**Planned:** bulk operations (batch status/role).

### 3.3 PoiCategories + fields + OSM import
**Status:** ✅ done — category CRUD, fields CRUD in edit form, auto-slug, OSM mapping + import (Overpass + local `.pbf`), category icon markers, unified audit.
**Planned:** DAO category verification.

### 3.4 Pois (points of interest)
**Status:** 🟡 partial — list/search/filter/pagination, detail (Details/Map/Audit), status moderation (incl. `imported`), reverse geocoding in the admin form, badges, map-live.
**Planned:** POI card by the unified pattern (tabs).

### 3.5 Voting / Community Moderation
**Status:** ✅ core done — polymorphic `Vote` (POI/photo/comment), badges «community approved/rejected» by threshold, `ReputationService`, 100m anti-fraud.
**Planned:** Suggested Edits (→ M1), photo auto-hide behavior on community reject (→ M1), tie reputation to levels (contribution-based, → M1).

### 3.6 Settings (admin notification settings)
**Status:** ✅ done — meaningful event switches, gamification in `Setting.gamification_config` + edit form in admin, autosave + toast + audit.
**Planned:** separation of admin event notifications by roles (Rolify).

### 3.7 Comments (admin moderation)
**Status:** ✅ done — list/filter/pagination, detail with audit, hide/unhide/delete (staff-only), user-status interaction gating, live comment update.
**Planned:** Lookbook previews for `Admin::Comments::*`, A/B specs for live comments.

### 3.8 Contracts (Contract Mgmt)
**Status:** 🔴 planned — admin section to manage **all three contracts** (TravelFiToken / TravelFiRewards / TravelFiCrowdsale). Service layer (`ContractService`) exists; UI missing. → [`MILESTONES.md`](MILESTONES.md) M2.

---

## 4. Horizontal layers

### 4.1 Auth & Roles
**Status:** ✅ — Devise (email + confirmable + lockable), Google OAuth, Pundit policies, Rolify (`admin`/`moderator`/`user`), user status model (`pending→active→inactive`, `suspended`/`banned`/`deleted`) with `suspended_until` + auto-unlock, `UserAccessService` classifier.

### 4.2 Gamification & Web3
**Status:** 🟡 — token model works (off-chain `UserReward` + `TokenTransaction` journal, on-chain relay, claim); 6 badges. **Decimals:** token = 18, jetton in TON = 9 (bridge maps 9↔18, no contract rewrite).
**Planned:** levels/badges by user contribution (→ M1), on-chain `balanceOf` as TFT-balance source of truth (→ M1), two wallets (custodial/external; external = MetaMask/hot-wallet; WalletConnect on future need) + EIP-2771 (→ M2), Token Spend (→ M2), Contract Mgmt UI (→ M2), distributed key storage / Vault (free service research, → M2).

### 4.3 Realtime infrastructure
**Status:** ✅ — StimulusReflex + CableReady + SolidCable, channels `UserChannel`/`AdminChannel`, SolidQueue + SolidQueueDashboard, SolidCache (infrastructure).

### 4.4 Audit (PaperTrail)
**Status:** ✅ — PaperTrail (Single Source of Truth) → `VersionObserverJob` → broadcasters; rule `update!`/`save!`, `update_all` forbidden for audited data.

### 4.5 Notifications (Noticed)
**Status:** 🟡 — in-app/database ✅, email — debt. Noticed 3.0.0, channel filtering via `Setting`, Web push.

### 4.6 i18n / UI (ViewComponents)
**Status:** ✅ — 4 locales (en/ru/es/zh), sidecar ViewComponents, green-blue Tailwind palette, MDI icons, UI library, lazy Stimulus controllers.
**Debt:** admin sidebar strings hardcoded (must move to i18n keys).

### 4.7 PWA / Devices
**Status:** 🟡 — manifest + service worker (App Shell, static cache, offline fallback), install icons. **Offline data** (IndexedDB, tiles) — planned (→ M3).

### 4.8 CI / Tests / Production
**Status:** 🟡 — CI (brakeman/bundler-audit/rubocop/yarn audit/rspec) exists; full RSpec suite green; **production deploy is the LAST step** (→ M3).

---

## 5. Relations + data flows

- **Reference chain (Database-Triggered Workflow):** Controller/Reflex → Service (Pundit + `save!` in a transaction) → PostgreSQL + PaperTrail → `VersionObserverJob` → Broadcaster (`inner_html`) → CableReady → ActionCable (SolidCable) → DOM. Full description — [`README.md`](README.md).
- **Channels:** `UserChannel` → `user_<id>` (personal) + `pois_map` (shared map); `AdminChannel` → `admin_<id>` (personal) + `admin_feed` (shared admin panel).
- **Entity graph:** see [`README.md`](README.md) (tables and flows) — not duplicated here.

> Versioning: ROADMAP is a living status; use `git log` for change history. Decisions are in README «Architectural decisions».
