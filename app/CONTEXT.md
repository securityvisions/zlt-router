# CONTEXT.md

Shared vocabulary for the Xirouter project (the router companion app). Use these terms
exactly; don't drift to synonyms. The router-side system has its own glossary in
`~/home-network/CONTEXT.md`; this file covers the app and the seam between them.

## Glossary

- **Xirouter** — this Android app (package `ir.parsavisions.xirouter`). A Persian RTL
  companion to the home-network Telegram bot: the same router data, richer surfaces.
- **Router API** — the JSON HTTP surface on the router (`/cgi-bin/routerapi.sh/*`), the
  single seam the app talks to. Defined in `API_CONTRACT.md`. One state, two surfaces:
  the API reads and writes the same files the bot uses.
- **Dashboard** — the app's home screen: a live summary (data balance gauge, proxy state,
  devices, today's usage, disk, load/temp) with tiles into the detail screens. Distinct
  from the bot's *Dashboard card* (a Telegram message).
- **Local history** — the phone's Room store of samples recorded on every poll. A second
  history store beside the router's *history logs*; charts merge the two, favoring local
  samples when the router is unreachable.
- **Sample** — one recorded history point (timestamp, kind, value). Kinds: `balance`
  (GB remaining) and `usage_today` (GB consumed today).
- **Snapshot** — one poll of router state used for alert diffing (balance tier, proxy,
  device set, disk, uptime, drain). The first snapshot baselines silently.
- **Live bandwidth** — the real-time per-device + total throughput screen, computed by
  diffing two `/live` cumulative-counter samples ~1 s apart.
- **Notification** — an in-app local notification, distinct from the bot's *Alerts*.
  Triggered by snapshot diffs on the same rules the bot's cron alerts use.
- **App lock** — the optional PIN gate (chandtoman pattern); destructive actions require
  it to be set.
- **Person (شخص)** — a named billing entity that owns one or more *device MACs*; the
  ledger's subject. Every statistic (usage, cost, payment) rolls up to it. A device with
  no owner is *unbilled*.
- **Device (دستگاه)** — a per-MAC entity on the router; the person-owned unit. Each has a
  local display alias (independent of the router-written name), watch state, and optional
  category/note.
- **Ledger (دفترحساب)** — the app's permanent, per-*Jalali month* archive of per-person
  entries: usage, owed, paid, notes. Backed by Room; survives years of history.
- **Owed (بدهی)** — a person's computed usage × rate for a month; **Collection (وصول)** is
  the sum actually paid in a period.
- **Data plan (طرح اینترنت)** — the account-level internet offering reported through the Router API.
  A Data plan may contain multiple simultaneous *Packages*; its balance is their aggregate.
- **Package (بسته)** — one independently tracked allowance within the Data plan, with provider
  identity, type/name, total, remaining, consumed, activation/expiry, status, and priority.
  Package amounts come from the router; Xirouter may add only local display metadata such as
  alias, color, category, visibility, note, and order.
- **Bill period** — the router's Gregorian month (`/etc/usage-log/YYYY-MM.log`) is the
  *source* for usage; the app's ledger re-keys it to the Jalali month by dominant overlap
  and by its own daily per-device recorder.
- **Owner suggestion** — deterministic device→person matching surfaced as suggestions;
  never auto-applied.
- **Ownership correction** — an explicit, previewed replacement of a Device’s historical
  Person/date interval. It may reopen affected Ledger months while preserving manual money data.
- **Person merge** — consolidation of a duplicate Person into one surviving Person, including
  current Devices and historical ownership/Ledger identity. It never reclaims Devices when an
  archived Person is merely restored.
- **Support bundle** — a manually exported, privacy-safe diagnostic archive containing bounded
  crash and operational history. It excludes credentials, Person notes, notification contents,
  and raw Router API responses.
