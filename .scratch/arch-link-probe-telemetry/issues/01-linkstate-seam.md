# 01 — LinkState seam

**What to build:** `X28` `Link` (operator / PLMN / tech / signal / RSRP / RSRP_5G / band / flow) becomes one `LinkState` deep module with a single `readLink()` seam — every consumer reads the same structured value and the `LinkPolicy.decide` table, instead of 4 `sed` readers and 3 `linkstate.sh` calls per tick.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] `LinkState {operator, plmn, tech, signal, rsrp, rsrp_5g, band, flow_dl, flow_ul}` + `LinkPolicy.decide` (existing `x28w_decide` logic) exposed via `hnlib.sh:hn_link_state` seam used by all consumers.
- [x] `x28-telemetry.sh` calls `readLink()` once per tick (was 3×); `x28-status.sh:gv`, `x28watch.sh:link_field`, `operator-watchdog.sh:cur_plmn` removed as duplicates.
- [x] Fixture test: `LinkState` JSON from `X28_FIXTURE_DIR/cmd401.json` correctly populates all fields.
