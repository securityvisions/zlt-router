# 04 — Confirm or rule out the partition-flip reboot mechanism

**What to build:** A documented conclusion on the periodic graceful reboots. Evidence from the diag logger established the *facts*; the question is which mechanism causes the reboots. Decision gate for everything after it.

**Blocked by:** 01, 02

**Status:** in-progress — facts captured; cause not yet closed.

**Established facts (diag logger evidence):**
- Three boots in ~30 min (15:01, 15:12, ~15:30), each `previous_shutdown=clean` — graceful software-initiated reboots, NOT crash/power-loss/watchdog.
- `flag_try_sys1_failed` climbed 20 → 21 because `S99bootcount` early-exits ("rd03 model detected") and never performs its reset. That climb is a *symptom* of the skipped reset, not proof the counter *causes* the reboots — any reboot would leave it climbing.
- 03 now zeroes the counters on every boot, so the climb is stopped. If the reboots stop too, the counter/partition-flip interaction was load-bearing; if they continue, the cause is elsewhere and the runtime-log tail will show it.

**Acceptance:**
- [ ] One boot cycle after 03: `bootcount_before=` shows 0/0 and stays 0/0.
- [ ] Reboots stop, OR a non-bootcount cause is identified from the runtime log tail and this ticket documents it.
