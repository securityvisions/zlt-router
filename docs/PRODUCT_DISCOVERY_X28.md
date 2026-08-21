# Product Discovery — X28 Brain: Safe Feature Ideation

**Date:** 2026-08-22 · **Product:** ZLT X28 smart-edge + @xirouterbot
**Objective:** Features that add daily value **without risking the only-WAN appliance**
**Constraint ladder (safest → riskiest):** read-only > device-scoped writes > network-affecting

---

## 1. Understanding the Opportunity

| Dimension | Answer |
|---|---|
| Product | ZLT X28 (`192.168.70.1`) running mihomo failover, Telegram Panel, telemetry stack, 6 procd daemons |
| Users | Technical owner (full control) + family members (consumers) |
| Pain today | Prepaid Samantel data runs out mid-month; MCI daytime congestion; no visibility into *who* used *what* until the bill; tunnel hangs need manual restarts (now auto-healed); kids' screen time unmanaged |
| Desired outcome | Never lose internet unexpectedly · never overpay for data · know what's happening without asking · fix things from anywhere |

**Existing assets to leverage (build on, don't rebuild):**
`hnlib.sh` pure functions (forecast, budget decision, cost table, health score, quality series, cooldown registry), `Telemetry log` (hourly rows since Aug 21), `Panel` inline keyboard framework, `tg-notify.sh` alert path, conntrack per-device sampler.

---

## 2. Ideation — 5 × 3 Perspectives

### 🟣 Product Manager — business value & strategic alignment

| # | Idea | Why it matters |
|---|---|---|
| PM-1 | **Data Budget Guardian** — forecast month-end usage from `hn_forecast_gb`, tiered Telegram alerts at 75/90/100% of a configurable budget | Samantel is prepaid — running out = hard stop. Prevents the #1 household pain. Builds directly on `hn_budget_decision` (already tested). |
| PM-2 | **Weekly Digest Card** — automated Friday-evening summary: GB used, Toman cost, top device, outage count, avg RSRP | Creates a habit loop; the data already exists in `Telemetry log` + `usage/day/*`; zero new sensors. |
| PM-3 | **ISP Outage SLA Ledger** — record every `internet_down` event with duration; weekly "MCI owed you 3h 40m" card | Turns frustration into evidence; differentiator no consumer router offers. Uses `hn_event_record(internet_down)` — event catalog already has the kind. |
| PM-4 | **Multi-admin roles** — second chat ID with read-only scope (spouse sees status, can't switch/kill) | De-risks "one person holds all control"; simple CHAT_ID_RO allowlist check. |
| PM-5 | **Maintenance window scheduler** — auto-reboot X28 at 05:00 Sunday if uptime >14d or RAM <50 MB (proven leak recovery) | Proactive stability; the reboot that fixed the WiFi wedge would have been automatic. |

### 🔵 Product Designer — UX, usability, delight

| # | Idea | Why it matters |
|---|---|---|
| D-1 | **Live trend charts as images** — render `RSRP 24h` / `speed 7d` / `usage 30d` as PNG (gnuplot or ASCII→SVG) attached to cards | Numbers tell; shapes convince. `Telemetry log` has the rows. |
| D-2 | **WiFi share QR** — `/wifi` generates a QR of `SSID+password` for guests | Classic delight moment; zero risk; guests stop typing passwords wrong. |
| D-3 | **Conversational queries** — free-text "how much data" / "is it up?" parsed to the same card handlers | Removes command memorization; the staleness guard + allowlist already protect this path. |
| D-4 | **Card theming** — status emoji reflect severity bands (🟢🟠🔴 from `hn_health_band`), consistent across every card | Instant glanceability; reuses ADR-0005's derived score. |
| D-5 | **Guided incident flow** — when an alert fires, its Card carries inline buttons ("Restart core" / "Switch to Rightel" / "Dismiss") | Closes the loop from *seeing* a problem to *fixing* it in one chat. |

### ⚙️ Software Engineer — technical possibilities & data leverage

| # | Idea | Why it matters |
|---|---|---|
| E-1 | **Kill-switch toggle** — `/killswitch on` flips fail-open to fail-CLOSED (block WAN when no alive node) for privacy-sensitive mode | The inverse of ticket 10; a flag on existing dns-fix logic, fully reversible. |
| E-2 | **Wake-on-LAN** — `/wol <device>` sends a magic packet from the bot to a known MAC | Tiny effort, high delight; purely additive packet, cannot affect routing. |
| E-3 | **Modem SMS reader** — vendor API has SMS cmds; surface Samantel/OTP texts as Telegram Cards | Data-balance texts arrive on the SIM in the modem — reading them closes the ISP-lag gap BALANCE.md documents. |
| E-4 | **Per-device DNS policy** — kid devices get ad-block + safe-search DNS; adults get standard | Reuses the adblock include pattern with a second dnsmasq tag; iptables `-m mac` marks. |
| E-5 | **Nightly config backup + drift diff** — tar configs to /data + repo, diff against last-known-good, alert on unexpected change | Would have caught the `lan_mgr` DNS regeneration instantly; extends the existing rollback snapshot. |

---

## Shipped — x28-smart-reports (2026-08-22)

All items below from §2 were shipped as read-only reports on the X28, safely (snapshot + health gate, no WiFi/modem writes).

| Shipped | Idea | Safety | Effort |
|---|---|---|---|
| ✅ | Data Budget Guardian — `/budget`, tiered warn/urgent/exhausted alerts via `hn_budget_tier` + `x28-budget.sh` (hourly telemetry tick, Jalali exhaustion date) | Read-only | S |
| ✅ | ISP Outage SLA Ledger — append-only ledger at `/data/proxy/outage-ledger.log`, `hn_outage_pair`/`hn_outage_total`, `/outages` per Jalali month | Read-only | S |
| ✅ | Weekly Digest Card — Friday 20:00 `x28-digest.sh` (GB+Toman, top devices, outage minutes, balance+forecast, RSRP/operator), `/digest` on demand | Read-only | S |
| ✅ | Per-person Jalali report — `owners.conf` + `hn_owner_of` + `x28-people.sh` + per-owner daily roll in `usage-collect.sh`, `/people` + `/month`, first-Friday-after-boundary auto-send | Read-only | M |
| ✅ | WiFi share QR — `/wifi` via `x28-wifi.sh` + `qrencode` (opkg/static fallback), `WIFI:S:` URI escaping, photo via `sendPhoto` | Read-only | S |
| ✅ | Vendor guest-SSID research — read-only discovery: MTK `l1profile.dat`/`mt7915` + `sub_wifi_thrd`, no safe native guest toggle; verdict: second SSIDs on recovered AX3000T | Read-only | S |
| ✅ | Jalali calendar module — `hn_greg_to_jalali`, `hn_jalali_to_greg`, `hn_jalali_month_range`, Persian labels in hnlib (awk breaks table, 53 tests) | Read-only | S |

Deferred from this batch: Nightly config backup+drift (next), Guided incident flow, Kill-switch (network-affecting, needs its own soak).

## 3. Prioritized Top 5 (across all perspectives)

Scored on: safety (house-internet risk) · value · effort · builds-on-existing.

| Rank | Idea | From | Safety tier | Effort | Why selected |
|---|---|---|---|---|---|
| **1** | **Data Budget Guardian** (PM-1) | PM | Read-only | S | Highest household value; `hn_forecast_gb` + `hn_budget_decision` are already unit-tested; alerts via existing tg-notify; zero network touch. |
| **2** | **Nightly config backup + drift alert** (E-5) | Eng | Read-only (+tar write to /data) | S | Directly prevents the class of incidents already suffered twice (lan_mgr wipe, hung core). The rollback snapshot proved the restore path works. |
| **3** | **Weekly Digest Card** (PM-2 + D-2 merged) | PM+D | Read-only | S | Friday cadence matches the existing Friday-rate logic (`hn_days_until_friday`); one Card combining usage/cost/outage/RSRP makes the whole system feel alive. |
| **4** | **Guided incident flow** (D-5) | Designer | Write (user-initiated only) | M | Every existing alert becomes actionable; buttons call already-proven paths (`restartSb`, `do_switch`). The UX leap from passive monitoring to one-tap remediation. |
| **5** | **Kill-switch toggle** (E-1) | Eng | Network-affecting (opt-in, default off) | S | Completes the resilience story for privacy-conscious moments; strictly a flag around ticket-10 logic; default stays fail-open so nothing changes unless asked. |

**Deliberately deferred:** per-device schedules and DNS policies (network-affecting, need their own soak), modem SMS (vendor cmd discovery is a mini-project), multi-admin (single-user household today).

---

## 4. Key Assumptions to Validate

| Idea | Assumption | Cheap validation |
|---|---|---|
| Budget Guardian | Samantel counters update fast enough post-download for useful alerts | Run `balance.sh --report` hourly for 48h; compare against conntrack delta (BALANCE.md says lag exists — measure it) |
| Nightly backup | Restore-from-tar works for every file type we back up | Drill: restore `mihomo-config.yaml` from backup to a scratch dir, checksum vs live (same drill as promotion ticket 01) |
| Weekly Digest | Friday 21:00 is when the user actually reads Telegram | Ship v1; if unread for 3 weeks, move time or demote to on-demand `/digest` |
| Guided incident flow | Inline-keyboard taps during an outage still deliver (Telegram works when tunnel is down? — currently **no**) | Test callback delivery during a forced fail-open episode; may need the digest fallback |
| Kill switch | User wants privacy-CLOSED more than availability in some windows | Ask: "should losing the tunnel ever mean losing the internet on purpose?" |

---

*Generated by the product trio session — safe-to-build features for the X28 brain, leveraging `hnlib.sh` deep modules and the existing Telemetry/Event infrastructure.*
