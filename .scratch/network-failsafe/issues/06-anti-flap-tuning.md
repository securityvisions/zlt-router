# 06 - Anti-Flap & Stability Tuning for URLTest and Watchdog

**Type:** `task`  
**Status:** resolved

## Resolution

1. **Sing-Box URLTest Anti-Flap Tuning:**
   - Increased `tolerance` to `150` ms (absorbs normal cellular latency jitter).
   - Increased check `interval` to `1m` (reduces probing frequency and overhead).
   - Removed `interrupt_exist_connections` so active file downloads and media streams are not abruptly terminated when sing-box adjusts background node preferences.
2. **Watchdog Dual-Endpoint & Hysteresis Hardening:**
   - Dual-endpoint probing: Google (`generate_204`) + Cloudflare (`cp.cloudflare.com/generate_204`). Failure is only flagged if BOTH endpoints fail.
   - Raised fail-open threshold to **5 consecutive cycles** (150s = 2.5 minutes of confirmed zero connectivity across both global CDNs).
   - Raised recovery threshold to **3 consecutive passes** (90s of confirmed stability) before re-engaging proxy interception.
3. Verified live: Google probe HTTP 204 in 0.81s, Cloudflare probe HTTP 204 in 0.79s, watchdog running cleanly.  
**Blocked by:** 05  

## Question

How to prevent aggressive node switching (flapping) and false-positive fail-open triggers during normal cellular jitter or single-endpoint slowdowns in Iran?

## Execution Plan

1. **Sing-Box URLTest Dampening:**
   - Increase `tolerance` to `150` ms (prevents minor ping fluctuations from rotating nodes).
   - Increase `interval` to `1m` (less frequent probing overhead).
   - Remove `interrupt_exist_connections` so active downloads/streams persist gracefully across background node preference shifts.
2. **Watchdog Robustness:**
   - Dual-endpoint health probe: Google (`generate_204`) AND Cloudflare (`cp.cloudflare.com/generate_204`). A failure is ONLY counted if both fail.
   - Increase fail threshold to 5 consecutive cycles (2.5 minutes of confirmed zero connectivity across both endpoints).
   - Increase recovery threshold to 3 consecutive passes (90s of confirmed stability) before restoring proxy interception.
3. Apply, test, and verify.
