# Travel Fi — Technical Debts Register

> **Purpose:** a living register of known technical debts and non-functional gaps. Each debt has an `id` (`D-*`), priority, owner section, and (where relevant) a link to the milestone that pays it off.
> **Priorities:** `🔴 High` (blocks/badly slows work) · `🟠 Medium` (should be done soon) · `🟡 Low` (nice to have).
> **Status lifecycle:** `Open` → `In progress` → `Closed`. When closing — move the row to «Closed» and note *when/why* (`git log` for the commit).
> **Related docs:** status → [`ROADMAP.md`](ROADMAP.md); grant estimate → [`MILESTONES.md`](MILESTONES.md); AI-agent instructions → `.roo/rules/*`; architecture → [`README.md`](README.md).

---

## 🔴 Open debts

| ID | Priority | Debt | Section | Milestone | Status |
|----|----------|------|---------|-----------|--------|
| `D-01` | 🟡 | **SolidCache is disabled in code** — infra configured, cache intentionally off (avoids stale during broadcast morphs). Restore selectively: static `ShowComponent` parts key `[category, I18n.locale]`; aggregates with collection dependency; **do NOT cache forms**. | 4.3 Realtime / 2.x Show | M3 (#4) | Open |
| `D-03` | 🟠 | **Contract monitoring (`ContractSnapshot`)** — no code; only on-chain sending via `TokenTransactionService.relay!`. Wishlist model (`contract_type`, `data jsonb`, `created_at`, rotation) to track contract state. | 3.8 Contracts | M2 | Open |
| `D-05` | 🟠 | **Noticed email channel not wired** — only database/action_cable/web_push in use; email delivery is a debt (needs SMTP + templates). | 4.5 Notifications | M3 (#5 deploy includes SMTP) | Open |
| `D-06` | 🟡 | **EIP-2771 integration and exchange UX remain pending** — the separate OpenZeppelin v5 `TravelFiForwarder` and backend relay flow are present. `TravelFiRewards` and `TravelFiCrowdsale` must expose `isTrustedForwarder(address)` for forwarder target validation; then deploy/configure the forwarder and three product contracts and verify trust. Automated coverage and cashier UI remain. ETH purchase principal is never sponsored; USDT purchases need allowance unless the token supports authorization. | 4.2 Gamification & Web3 | M2 | In progress |
| `D-07` | 🟡 | **`Token Spend` is a placeholder** — only a `direction: debit` marker; no feature-purchase flow. | 4.2 Gamification & Web3 | M2 | Open |
| `D-08` | 🟡 | **On-chain `balanceOf` not wired as TFT-balance source of truth** — UI shows internal `sum(claimed)` flag, not the real on-chain balance/reconciled value. | 4.2 Gamification & Web3 | M1 (#3) | Open |
| `D-11` | 🟠 | **Responsive layout gaps across user/admin pages** — audit and fix viewport overflow, fixed-width grids, long unbroken text, modal sizing, and touch-sized controls. Prioritize POI details/forms and map overlays, then profiles/auth and admin tables/forms; verify at narrow phone, tablet, and desktop widths. | UI / all sections | — | In progress |

---

## ✅ Closed debts

| ID | Debt | Closed |
|----|------|--------|
| `D-02` | `Ui::ConfirmDialogComponent` is already a standalone component reused across admin, voting, comments, and navigation flows. The POI detail/form overlay is separate UI and is not part of this debt. | 2026-10-09 — verified the existing shared confirmation dialog; no additional component was needed. |
| `D-04` | Admin navigation labels moved to en/ru/es/zh locale keys. | 2026-10-09 — layout now uses I18n for navigation labels. |
| `D-09` | Proximity checks already use the shared `PoiService.within_range?` helper; existing service specs cover missing coordinates, in-range, out-of-range, and staff bypass. | 2026-10-09 — verified service, policy, comment UI, photo, and Reflex paths share the helper. |
| `D-10` | Live comments are available to all viewers of a POI card; comment vote counters are broadcast to the shared stream. | 2026-10-11 — `PoiComment`/`Vote` updates route to `pois_map`; the creator's form is cleared through their personal stream. |

---

> **Rule:** a milestone's Definition of Done (see [`MILESTONES.md`](MILESTONES.md)) should not be considered met while the linked `D-*` debts referenced by that milestone remain `Open`.
