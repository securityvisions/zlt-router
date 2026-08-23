# 03 — Per-device traffic breakdown in ledger range CGI

**What to build:** The ledger-range CGI endpoint returns per-device rows alongside per-person totals. The dashboard's expandable breakdown section shows each person's devices with individual GB values, so the user can see WHICH device consumed the data, not just the total.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [ ] ledger-range.sh returns {entries:[...], breakdown:[{person,mac,bytes}...]}
- [ ] Dashboard expandable section renders per-device rows under each person
- [ ] MAC addresses resolved to hostnames when available in current leases
- [ ] Fixture test: multi-person multi-device data produces correct breakdown
