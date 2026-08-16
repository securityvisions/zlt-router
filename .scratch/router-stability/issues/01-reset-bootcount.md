# 01 — Reset the Xiaomi bootcount failover counters

**What to build:** The abnormal failover counters (`flag_try_sys1_failed=21`, `flag_try_sys2_failed=8`) are reset to `0` on the router — the same operation the firmware performs on a normal boot. Gives the next reboot a clean reference point so any further climb is measurable evidence.

**Blocked by:** None — can start immediately.

**Status:** resolved (fw_setenv → 0/0, confirmed by fw_printenv)

- [x] `fw_printenv` shows both counters at 0.
- [x] The reset is recorded in the session log.
