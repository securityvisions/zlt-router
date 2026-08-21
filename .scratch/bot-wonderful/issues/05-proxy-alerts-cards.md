# 05 — Proxy & Alerts as Cards

**What to build:** `Proxy` card shows `mihomo` `auto` `vps-reality`/`cdn-ws`/`hy2` `delay` with one-tap `Switch` (reuses `do_switch` storm guard) and `Alerts` (`thermal overheat`, `quality_degraded`, `operator_reselected`) all via `Notifier` as Cards.

**Blocked by:** 01 — Panel framework + beautiful Card seam, 02 — Wonderful Status/Link/Dashboard card

**Status:** resolved

- [x] `Proxy` card lists `auto` group nodes with `delay` + `alive` + one-tap `Switch` buttons per node; switch reuses `do_switch` and edits the card.
- [x] `Alerts` (`thermal overheat`, `quality_degraded`, `operator_reselected`) render via `Notifier` as Cards with `alert_text` + `Card` anatomy.
- [x] `Link` RSRP context from `02` appears in `Proxy` card when `Link` is degraded.
