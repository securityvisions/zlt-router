# 05 — Boot-race self-heal: wait for the TUN before routing

**What to build:** At boot, the persist hook runs before the engine finishes creating its TUN device, every route add fails silently, and the box looks configured while voice stays broken (the exact outage being fixed in 04). The enable script must instead wait briefly for the TUN device to appear before adding routes, fail LOUDLY (nonzero exit + clear message) if it never does, and verify each route actually landed. Fixture tests drive a fake ip binary whose device appears after N probes, covering: immediate success, delayed appearance, and never-appears failure.

**Blocked by:** None — independent code hardening.

**Status:** resolved

- [x] Script waits (bounded, configurable) for the TUN device before adding routes
- [x] Never-appears case exits nonzero with a clear operator-facing message — no more silent success
- [x] Post-add verification confirms every CIDR actually routed; partial failure exits nonzero
- [x] Existing behaviors preserved: idempotent re-run, --persist hook install
- [x] Fixture tests cover immediate/delayed/never cases via the fake-ip seam

## Answer

Enable script gained a bounded wait (default 30 s, `STEAM_TUN_WAIT` override), loud nonzero failure with operator message if the TUN never appears, and post-add verification per CIDR. Fixture tests extended via countdown fake-ip seam: immediate / delayed-appearance / never cases (14 assertions). Deployed to the device and exercised live.
