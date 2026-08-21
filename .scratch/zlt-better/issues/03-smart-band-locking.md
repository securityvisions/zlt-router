# 03 — Smart band locking

**What to build:** Probe vendor `TRAFFIC_*` bands via `x28lib.sh`, lock the best RSRP combo via `lockBand` vendor API, verify `Link` gain — reversible with one API call, never PLMN lock.

**Blocked by:** 01 — Thermal guard + overheat alert.

**Status:** resolved

- [x] `x28-band.sh` enumerates bands, tests RSRP delta, locks best combo, verifies `Link` RSRP gain/no loss via `linkstate.sh`.
- [x] One-liner revert (`lockBand` clear) restores auto; health gate GREEN; documented in `router/x28/README.md`.
- [x] Never touches `cmd 219` (PLMN lock); only `lockBand` vendor path.
