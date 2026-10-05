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
| `D-02` | 🟡 | **`Ui::ConfirmDialogComponent`** — extract the modal into a standalone component; remove the hand-written window from `Poi::ShowComponent`/`Poi::FormComponent`. | UI | — | Open |
| `D-03` | 🟠 | **Contract monitoring (`ContractSnapshot`)** — no code; only on-chain sending via `TokenTransactionService.relay!`. Wishlist model (`contract_type`, `data jsonb`, `created_at`, rotation) to track contract state. | 3.8 Contracts | M2 | Open |
| `D-04` | 🟡 | **Admin sidebar strings are hardcoded** in the layout — must be moved to i18n keys (4 locales). | 4.6 i18n/UI | — | Open |
| `D-05` | 🟠 | **Noticed email channel not wired** — only database/action_cable/web_push in use; email delivery is a debt (needs SMTP + templates). | 4.5 Notifications | M3 (#5 deploy includes SMTP) | Open |
| `D-06` | 🟡 | **External wallet UX is not built** — only custodial auto-wallet; connecting an external wallet (MetaMask / hot-wallet) + EIP-2771 sponsorship flow is pending. | 4.2 Gamification & Web3 | M2 | Open |
| `D-07` | 🟡 | **`Token Spend` is a placeholder** — only a `direction: debit` marker; no feature-purchase flow. | 4.2 Gamification & Web3 | M2 | Open |
| `D-08` | 🟡 | **On-chain `balanceOf` not wired as TFT-balance source of truth** — UI shows internal `sum(claimed)` flag, not the real on-chain balance/reconciled value. | 4.2 Gamification & Web3 | M1 (#3) | Open |
| `D-09` | 🟠 | **Proximity/anti-fraud consistency** — 100m checks live in services/policies; a single shared helper (vs duplicated `within_range?` calls) is a cleanup debt. | 3.5 Voting / SuggestedEdits | — | Open |
| `D-10` | 🟡 | **`PoiComment` live only for the author** — broadcasting is author-scoped; live for everyone is planned. | 2.2 POI Map / 3.7 Comments | M1 (#6) | Open |

---

## ✅ Closed debts

_Empty. Rows are moved here from «Open» once resolved (with a note on when/why)._

---

> **Rule:** a milestone's Definition of Done (see [`MILESTONES.md`](MILESTONES.md)) should not be considered met while the linked `D-*` debts referenced by that milestone remain `Open`.
