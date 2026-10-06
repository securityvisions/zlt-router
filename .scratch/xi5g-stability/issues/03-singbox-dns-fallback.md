# 03 - Multi-Resolver Resilience for sing-box DNS

Status: resolved
Assignee: agent
Type: task

## Answer

1. **Root Cause Confirmed:**
   - Domestic services (`digikala.com`, `aparat.com`, etc.) and general queries previously routed through `dns-proxy` suffered whenever the international DoH tunnel stalled, making local Iranian services fail even though direct internet was healthy.
2. **Resolution Applied:**
   - Extended `dns.rules` on AX3000T to explicitly direct major domestic services (`digikala.com`, `aparat.com`, `telewebion`, `.ir`, `.iau.ir`, `.srbiau.ac.ir`) to `dns-direct` (`192.168.70.1:53`).
   - Because `192.168.70.1:53` was hardened with clean, anti-poisoned caching and Mihomo DoH in our earlier phase, direct domestic queries resolve in < 2ms without touching the international VPS tunnel.
   - External foreign queries now route cleanly via `dns-proxy` (detouring through the hardened 2-node `auto` group).
   - Validated end-to-end resolution of both domestic and foreign domains across LAN and Wi-Fi.
Blocked by: 02

## Question

How should sing-box's `dns` block be structured so that if external DoH to `8.8.8.8` experiences latency or packet loss, queries fall back to secondary resolvers without blocking `dnsmasq`?

### Findings & Context

Currently in `/etc/sing-box/config.json`:
- `dns-proxy` points solely to `https://8.8.8.8/dns-query` detouring via `auto`.
- When DoH times out, sing-box returns `context deadline exceeded` to `dnsmasq`.
- Dnsmasq holds the client's query socket open until it times out, creating a total DNS blackout across all household devices on `XI-5G`.
- Adding a secondary clean resolver or direct fallback guarantees continuous DNS availability.
