# Feature Request Analysis — X28 Dashboard

**Product:** X28 household network dashboard (LAN-only web UI at :8080)
**User:** Single technical owner (parsa) managing a household network for 2–3 people
**Goal:** Reliable, visually clear network management without SSH or command-line access

---

## 1. Product Objective

Give the owner a single web page where they can see everything about their network at a glance and manage everything safely — without ever needing to SSH into the router or remember CLI commands. The dashboard should be the primary interface (per ADR-0004), with Telegram bot as the secondary/remote surface.

---

## 2. Feature Requests (raw, categorized)

### Theme: Data Visibility

| Request | Source | Status |
|---|---|---|
| Per-person usage for ANY Jalali date range | User (explicit) | ✅ Shipped (ledger-range CGI) |
| Package data remaining prominently | User (explicit) | ✅ Shipped (hero widget) |
| Daily ledger view | User (explicit) | ✅ Shipped (--daily mode) |
| Yearly ledger view | User (explicit) | ✅ Shipped (--yearly mode) |
| RSRP trend chart (72h) | Agent proposal | ✅ Shipped |
| Daily usage bar chart (30d) | Agent proposal | ✅ Shipped |
| Outage timeline visualization | Agent proposal | ✅ Shipped |
| Speed test from dashboard | Agent proposal | ❌ Not built |
| Signal quality history (weekly/monthly trends) | Gap identified | ❌ Not built |
| Per-device traffic breakdown (not just per-person) | Gap identified | ❌ Not built |

### Theme: Device Management

| Request | Source | Status |
|---|---|---|
| Assign users to MAC addresses | User (explicit) | ✅ Shipped (chip-based UI) |
| Better assignment UX | User ("awful") | ✅ Shipped (chip redesign) |
| Add new person inline | User (implied) | ✅ Shipped (➕ new flow) |
| Rename person | User (implied) | ✅ Shipped (/owner rename) |
| Per-device traffic breakdown | Agent proposal | ❌ Not built (data exists in owners-d) |
| Device nickname editing | Gap identified | ❌ Not built |
| New-device-joined notification | Agent proposal | ❌ Not built |

### Theme: Control & Actions

| Request | Source | Status |
|---|---|---|
| Reboot from dashboard | User (implied) | ✅ Shipped |
| Switch ISP from dashboard | User (full control choice) | ✅ Shipped |
| Toggle adblock | User (full control choice) | ✅ Shipped |
| Restart proxy engine | User (implied) | ✅ Shipped |
| Toggle rescue pool | User (implied) | ✅ Shipped |
| Add proxy node from URI | User (explicit: "add configurations") | ✅ Shipped |
| Test proxy node delay | User (explicit: "testing them") | ✅ Shipped |
| Switch between proxy configs | User (explicit: "switching between them") | ✅ Shipped |
| Service restart from dashboard | Agent proposal | ✅ Shipped |
| Guided incident flow (alert cards with fix buttons) | Deferred from smart-reports | ❌ Not built |
| Kill-switch toggle | Deferred | ❌ Not built |

### Theme: Reliability & Trust

| Request | Source | Status |
|---|---|---|
| Budget feature working reliably | User ("budget feature not working") | ✅ Fixed (grep -oP → sed, cache repopulated) |
| Nothing breaks the router | User (repeated emphasis) | ✅ Enforced (additive-only architecture) |
| Data survives reboot | User (implied) | ✅ owners-d + ledger persist |
| Dashboard always available when home | User (implied) | ✅ LAN-only busybox httpd |

### Theme: Polish & UX

| Request | Source | Status |
|---|---|---|
| Clean, scannable messages | User ("wtf is this shit") | ✅ HTML formatting system |
| Better assignment UX | User ("awful") | ✅ Chip-based redesign |
| Premium visual design | User (taste-skill request) | ✅ Outfit font + refined palette |
| Mobile responsive | Stated requirement | ⚠️ Partially — cards stack but tables may overflow |

---

## 3. Gap Analysis — What's Still Unsatisfied

Using Dan Olsen's Opportunity Score = Importance × (1 − Satisfaction):

### High Opportunity (importance high, satisfaction low)

| Opportunity | Importance | Current Satisfaction | Opportunity Score | Evidence |
|---|---|---|---|---|
| **Ledger doesn't update after assignment** | High — user expects it | Low — assignments only affect future rollups | **0.8** | User: "assign device and ledger not satisfying me" |
| **Budget data unreliable** | High — core financial visibility | Medium — fixed but depends on balance.sh cache being fresh | **0.6** | User: "budget feature also not working" |
| **No per-device traffic breakdown** | Medium — user wants to see WHICH device used WHAT | Zero — owners-d has the data but no UI renders it per-device | **0.5** | Implicit in "manage it easily" |
| **Dashboard feels incomplete** | Medium — user keeps asking for "more features" | Medium — good cards exist but lack depth (no historical trends beyond 72h/30d) | **0.5** | User: "i need more features" |

### Medium Opportunity

| Opportunity | Importance | Current Satisfaction | Opportunity Score |
|---|---|---|---|
| Speed test from dashboard | Medium — useful for diagnosing slow speeds | Zero — not built | 0.4 |
| Notification preferences | Medium — too many alerts = noise | Zero — all alerts hardcoded | 0.35 |
| Service health detail | Low-medium — services panel exists but minimal | Medium — shows status but no detail | 0.3 |

---

## 4. Top 3 Prioritized Features

### #1: Ledger Re-attribute + Auto-Refresh

**What:** When a device is assigned to a person on the dashboard, ALL historical owners-d data for that MAC should be immediately re-attributed to the new person, and the ledger card should refresh to show the corrected attribution.

**Why:** The user explicitly said "assign device and ledger not satisfying me." The current behavior requires running a separate `/owner reattribute` command after assigning. The user expects assignment to immediately update ALL data.

**Impact:** High — this is the core promise of the owner system ("assign once, see all data attributed")
**Effort:** Low — the reattribute logic already exists in x28-owners.sh; just call it automatically after assign
**Risk:** Low — idempotent operation on existing data
**Strategic alignment:** Direct — this is the "manage people and devices" use case

**Test:** Assign a device with historical data → verify ledger updates within 2 seconds without manual reattribute

---

### #2: Budget Data Reliability

**What:** The budget hero widget and budget card should ALWAYS show current data, never blank. The balance report cache should be refreshed automatically when stale, not require manual intervention.

**Why:** The user said "budget feature also not working." The root cause was an empty balance report cache after reboot. The fix (populating the cache) worked but the underlying fragility remains — any reboot or cache loss makes the budget disappear again.

**Impact:** High — budget/cost visibility is a primary user need
**Effort:** Medium — need a procd loop that refreshes the balance cache periodically (like the existing adblock refresh pattern)
**Risk:** Low — balance.sh already works, just needs scheduling
**Strategic alignment:** Direct — "know how much data is remaining" is a stated requirement

**Test:** Clear /tmp/balance_report → wait for refresh cycle → verify budget.json repopulates

---

### #3: Per-Device Traffic Breakdown on Dashboard

**What:** The Ledger card's expandable section should show per-DEVICE traffic (not just per-person totals) for the selected date range. Each person's row expands to show which of their devices used how much.

**Why:** The user said "manage it easily and better." Knowing that parsa used 2 GB is useful, but knowing that Nothing-Phone-2 used 1.5 GB and laptop used 0.5 GB is actionable — you can throttle a specific device or investigate unusual usage.

**Impact:** Medium-high — granular visibility into which device is consuming data
**Effort:** Medium — the owners-d data already has per-device rows (person|mac|up|down); just needs a breakdown renderer in the CGI and frontend
**Risk:** Low — read-only aggregation of existing data
**Strategic alignment:** Supports the "manage it easily" goal by making data actionable at the device level

**Test:** Query a date range with multiple devices per person → verify breakdown shows each device separately

---

## 5. Assumptions & How to Test

| Assumption | How to Test | Effort |
|---|---|---|
| User checks dashboard daily | Add a simple page-view counter; check after a week | Trivial |
| Re-attribute is fast enough for real-time UX | Time the operation on 35 days of data; target <2s | Trivial |
| Balance cache refresh every 15 min is sufficient | Monitor staleness over 48h | Low |
| Per-device breakdown is useful (vs per-person only) | Ship it, see if the user expands the section | None |

---

## 6. Recommended Next Steps

1. **Auto-reattribute after assign** (ticket 01) — smallest effort, biggest UX improvement
2. **Budget cache refresh loop** (ticket 02) — eliminates the "budget not working" class of bugs
3. **Per-device breakdown in CGI** (ticket 03) — exposes data that already exists but isn't rendered

These three together address every "not satisfying" complaint the user has raised, using data and scripts that already exist.
