# 03 - ProbeService seam for BOTH devices (which callers migrate, where does it live)

Status: resolved
Type: grilling

## Question

ProbeService (router/x28/probe-service.sh) is the intended single health-check seam, but it lives on X28 only, and AX3000T's proxy-watchdog.sh has its own dual-endpoint probe. Decisions to walk:

1. Which of the 5 probe implementations migrate to ProbeService, and in what order (dns-fix inline fallback, x28-vps-heal auto-grep, operator-watchdog curl, AX3000T proxy-watchdog dual-endpoint)?
2. Does AX3000T get its own copy of probe-service.sh (deployed like other repo-authored tools), and do the two copies share one canonical repo file with per-device profile config?
3. What is the exit-code contract every caller must honor (tonight's bug: `echo dead` returned 0)?
4. Which env seams make it testable fixture-first in router/tests/ (pattern: test_dns.sh)?

## Answer

1. **Unified Multi-Endpoint Architecture:** Deepened `router/x28/probe-service.sh` to encapsulate:
   - Remote DNS resolution via `socks5h://$socks` instead of `--socks5`, preventing local DNS poisoning from killing probe handshakes.
   - Dual-endpoint resilience: if primary `$PROBE_URL` (Google 204) fails, automatically falls back to secondary `$PROBE_FALLBACK_URL` (`http://cp.cloudflare.com/generate_204`) before declaring failure.
   - Fail-open direct connectivity check (`probe_check_direct`) with gateway ping fallback.
   - Strict exit code contract: exit `0` on alive (HTTP 200/204), exit `1` on dead.
   - Automatic SOCKS port selection: defaults to `127.0.0.1:1080` when sing-box is present (AX3000T), and `192.168.70.1:1080` on X28.
2. **Caller Migration:**
   - `router/proxy-watchdog.sh` delegates to `/usr/sbin/probe-service.sh check passwall` and `/usr/sbin/probe-service.sh direct` (retaining inline fallbacks if standalone).
   - `router/x28/operator-watchdog.sh` delegates `check_data()` to `/data/proxy/probe-service.sh data`.
   - `router/netpull.sh` manifest tracks `probe-service-ax` to mirror canonical probe logic to AX3000T.
3. **Verification:**
   - `test_probe_telemetry.sh` passes 11/11.
   - `test_netpull.sh` passes 10/10.
   - `test_x28watch.sh` passes 9/9.
