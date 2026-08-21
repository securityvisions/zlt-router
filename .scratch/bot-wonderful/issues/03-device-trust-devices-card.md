# 03 — Device Trust + Devices card

**What to build:** `Device Trust level` (`Trusted/Known/Guest/Unknown/Blocked`) is implemented; `Devices` card lists every `Device` with `dev_usage_rows` bars + one-tap `Block`/`Approve` (wires `quarantine.sh:1`). Unknown device triggers `Alerts` as a Card.

**Blocked by:** 01 — Panel framework + beautiful Card seam

**Status:** resolved

- [x] `Devices` card lists `mac|name|trust|today_gb` with `dev_usage_rows` bars + `Block`/`Approve` inline buttons per `Unknown`/`Blocked`.
- [x] Tapping `Block`/`Approve` flips `Device Trust level` and edits the card in place; `Alerts` fires as a Card on `Unknown` join.
- [x] `quarantine.sh` is the single Trust writer; no duplicate state files.
