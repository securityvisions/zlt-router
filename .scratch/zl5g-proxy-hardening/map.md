# ZL-5G Proxy & Routing Hardening Map

Label: `wayfinder:map`

## Destination

Eliminate selective access failures and service blackouts on ZL-5G (Tozed ZLT X28) by fixing DNS poison caching in dnsmasq, enabling Mihomo SNI sniffing, establishing UDP transparent proxying for voice/media applications, updating the active node pool in Mihomo, and hardening the fail-open probe logic.

## Notes

- Domain: Cellular gateway routing, DNS anti-poisoning, Mihomo transparent proxy, iptables TPROXY.
- Target device: Tozed ZLT X28 (`192.168.70.1`).
- Skills to consult: `diagnosing-bugs`, `domain-modeling`, `grilling`.
- Standing preferences: Zero system reboots, never break AX3000T (`192.168.70.2`) bypass (`RETURN` in `X28_SPLIT`).

## Decisions so far

- [01 - Eliminate dnsmasq DNS Poison Caching on X28](issues/01-dnsmasq-cache-poisoning-flush.md): Flush dnsmasq cache on mode transitions via full restart + clear-on-reload, eliminating persistent 10.10.34.35 poisoning.
- [02 - Enable Domain Sniffing in X28 Mihomo Engine](issues/02-mihomo-sniffing-and-fakeip.md): Enable TLS/HTTP sniffing with override-destination in Mihomo, ensuring domain rules intercept hijacked/unmapped IPs.
- [03 - Align ProbeService & dns-fix Contract on X28](issues/03-probe-service-and-dns-fix-contract.md): Re-anchor ProbeService to Mihomo :1080 and enforce non-zero exit codes on failure for authentic fail-open.
- [04 - Transparent Proxying for UDP Voice and Media on ZL-5G](issues/04-udp-voice-media-interception.md): Document kernel xt_TPROXY absence, maintain QUIC drop for fast HTTP/2 fallback, and implement persistent X28_DNS interception for hardcoded DNS clients.
- [05 - Rebalance Mihomo Node Pool & Latency Selection](issues/05-mihomo-proxy-pool-health.md): Standardize health check endpoints and convert group world from static select to auto fallback to rescue pool.

## Not yet specified

- Full migration of X28 transparent interception from NAT REDIRECT to pure TPROXY for unified TCP+UDP flow.
- Automated purging of dead proxy provider subscriptions and rescue pools in Mihomo.

## Out of scope

- Modifying proprietary MediaTek/Quectel cellular modem binaries (`lan_mgr`, `ql_netd`).
- Moving primary household Wi-Fi clients off AX3000T (`XI-5G`) onto X28 (`ZL-5G`).
