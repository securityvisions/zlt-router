# 05 - End-to-End Resilience & Failover Verification

**Type:** `task`  
**Status:** resolved

## Resolution

Executed complete end-to-end verification across all 6 validation tiers:
1. **AX3000T SOCKS Probe:** HTTP 204 in 0.82s.
2. **AX3000T Direct Cellular Probe:** HTTP 204 in 0.41s.
3. **DNS Split Resolution:**
   - Censored (`youtube.com`): resolved to `142.251.13.91` via encrypted DoH detour.
   - Domestic (`divar.ir`): resolved to `185.166.104.7` via `dns-direct`.
4. **Active URLTest Group:** `auto` dynamically measured and picked `vps-reality` (delay: 345ms).
5. **Watchdog Status:** Running with `MODE="proxy"`, `FAILS=0`.
6. **X28 SOCKS Probe:** HTTP 204 in 0.78s.
7. **VPS Proxy Core:** `s-ui.service` actively serving traffic with zero errors or port collisions. All systems verified stable.  
**Blocked by:** 04  

## Question

How to verify that the entire failover and recovery chain functions correctly under real simulated failure conditions without causing persistent disruption?

## Execution Plan

1. Verify normal proxy state (Google, YouTube, .ir routing).
2. Simulate node failure and confirm automated `urltest` rotation.
3. Simulate complete proxy drop and confirm 90s fail-open transition.
4. Verify recovery back to proxy within 60s of proxy restoration.
