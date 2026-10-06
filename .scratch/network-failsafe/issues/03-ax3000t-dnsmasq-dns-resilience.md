# 03 - Sing-Box DNS Timeout & DoH Resilience on AX3000T

**Type:** `task`  
**Status:** resolved

## Resolution

1. Updated `dns.servers` in `/etc/sing-box/config.json`: changed `dns-proxy` detour from static `proxy-select` to resilient `auto` (`urltest`).
2. Clean DoH resolution (`https://8.8.8.8/dns-query`) now rides dynamically over whichever node in `auto` (`vps-reality`, `hy2`, `via-x28`, `cdn-ws`) is currently responding with lowest latency.
3. Verified domestic and foreign DNS resolution:
   - Foreign (`google.com`): resolved via `dns-proxy` in <50ms.
   - Domestic (`varzesh3.com`): resolved directly via `192.168.70.1` (`dns-direct`) in <10ms.
   - Verified zero dnsmasq slot hangs.  
**Blocked by:** 02  

## Question

How to prevent sing-box DNS resolution from hanging indefinitely when proxy nodes drop, avoiding `dnsmasq` slot exhaustion across the home LAN?

## Execution Plan

1. In `/etc/sing-box/config.json`:
   - Set `dns-proxy` DoH server detour to `auto`.
   - Configure DNS rule evaluation and reduce query exchange timeouts.
2. Verify that local `.ir` domains continue resolving directly via `192.168.70.1`.
3. Test end-to-end resolution latency from LAN client.
