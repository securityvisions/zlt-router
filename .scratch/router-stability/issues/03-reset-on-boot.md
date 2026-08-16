# 03 — Reset the failover counters on every boot (fix the early-exit skip)

**What to build:** The stock `S99bootcount` early-exits ("rd03 model detected") before resetting `flag_try_sys{1,2}_failed`, so the counters climb forever and u-boot keeps rebooting. The fix lives in the diag logger (the script we own and deploy): after recording the pre-boot values, it resets both counters on a confirmed boot — the same operation S99bootcount would perform. Verified by a reboot showing the counters still at 0 and a clean shutdown marker.

**Blocked by:** 01, 02

**Status:** resolved (diag.init `diag_bootcount_reset`; counters 0/0 after `boot()`)

- [x] On a confirmed boot the counters are zeroed after capture.
- [x] The reset is guarded (no `fw_setenv` → no-op; initramfs → no-op).
- [x] A reboot leaves both counters at 0.
