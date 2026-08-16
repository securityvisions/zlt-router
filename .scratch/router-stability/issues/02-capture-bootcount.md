# 02 — Capture bootcount flags in every boot entry

**What to build:** The reboot logger's boot entry records the failover counter values (`flag_try_sys{1,2}_failed`) alongside the clean-vs-crash marker and dmesg tail. One file self-documents whether the counters climbed since the last boot — the missing evidence for the partition-flip theory.

**Blocked by:** None — can start immediately.

**Status:** resolved (diag.init `bootcount_before=` line; `test_diag.sh` green)

- [x] Every boot entry includes a `bootcount_before=` line with both counters.
- [x] The capture is fixture-tested (climbed block → captured verbatim).
