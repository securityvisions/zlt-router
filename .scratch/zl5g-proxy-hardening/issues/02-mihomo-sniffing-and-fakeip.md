# 02 - Enable Domain Sniffing in X28 Mihomo Engine

Status: resolved
Assignee: agent
Type: task

## Answer

1. **Root Cause Confirmed:** Mihomo ran with `"sniffing": false`. Transparent traffic arriving on port 12345 was routed purely by raw destination IP without domain identification. When any domain resolved to an unexpected or sinkholed IP (like `10.10.34.35`), Mihomo could not match `GEOSITE,youtube` or other domain rules and routed the traffic into the `10.0.0.0/8` direct blackhole.
2. **Resolution Applied:**
   - Configured the `sniffer:` block in `/data/proxy/mihomo/config.yaml` with `parse-pure-ip: true`, `force-dns-mapping: true`, HTTP on ports `80, 8080-8880` with `override-destination: true`, and TLS on `443, 8443`.
   - Verified the configuration using `/data/proxy/mihomo/mihomo -t -d /data/proxy/mihomo`.
   - Reloaded configuration dynamically via Mihomo API `PUT http://127.0.0.1:9090/configs` with zero downtime.
   - Updated template in repository `router/x28/mihomo-config.yaml`.
3. **Verification:** Executed an adversarial test by pointing `youtube.com` deliberately to poisoned IP `10.10.34.35:443` across transparent interface `eth1`. Mihomo successfully sniffed the SNI `youtube.com` from the TLS ClientHello, overrode destination, and returned HTTP/2 301 from Google's official server in 1.4s.
Blocked by: 01

## Question

How should Mihomo's `sniffing` and DNS configuration be updated in `/data/proxy/mihomo/config.yaml` to detect domain names from TLS ClientHello / HTTP Host and prevent blackholing when destination IPs are unmapped or sinkholed?

### Findings & Context

Currently `curl -s http://127.0.0.1:9090/configs` reveals `"sniffing": false`. Transparent traffic on X28 arrives via iptables `REDIRECT --to-ports 12345` (TCP redir-port). Because sniffing is disabled, Mihomo cannot inspect TLS ClientHello SNI. If a domain resolved to an unexpected IP or a previously cached address, Mihomo matches `IP-CIDR, 10.0.0.0/8, DIRECT` or `MATCH, world` without domain rule matching (`GEOSITE, youtube`, `GEOSITE, google`, etc.), breaking service routing.
