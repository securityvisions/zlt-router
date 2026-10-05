# ADR-0008: Emergency DNS Tunneling (dnstt) Failover Tier

Date: 2026-09-29 · Status: accepted · Deciders: parsa + agent

## Context

During severe censorship events and national internet blackouts ("روز قطعی" / National Information Network isolation):
1. All standard UDP ports (443/QUIC, WireGuard, Hysteria2, TUIC) are dropped or throttled to zero.
2. Direct TCP connections to foreign VPS providers (Hetzner, Servitro, DigitalOcean) are subjected to RST injection or IP-level blocking.
3. TLS ClientHello fragmentation is neutralized by DPI stateful TCP-reassembly.
4. The sole surviving outbound communication channel is UDP port 53 (DNS) routed through domestic recursive resolvers (MCI, Irancell, TCI, `10.10.34.35`, `4.2.2.4`, `8.8.8.8`).

Prior to this decision, the network resilience chain terminated at **Fail-open** (dropping to direct domestic internet). In a blackout scenario, direct internet provides zero access to international services, messaging, or threat intelligence.

## Decision

1. **Deploy dnstt-server on VPS 1 (`85.121.124.158`):**
   - Daemon runs under systemd as `dnstt.service`.
   - Listens on `:53 UDP`, terminates Noise/KCP tunnel framing, and hands payload streams to Cloudflare WARP on `127.0.0.1:40000`.
   - Unrecognized DNS queries fall back to `1.1.1.1:53`.
   - Zone root: `t.dmbz.ir`.
   - Cryptographic identity: Server Noise public key `3ac91e6d9222cefc2535c22a83bb9be88353c0bfb63e1698cc13cbb82498946a`.

2. **Authoritative Delegation (Cloudflare DNS):**
   - `A` Record: `ns.dmbz.ir` → `85.121.124.158` (DNS-only / Grey Cloud, TTL Auto).
   - `NS` Record: `t.dmbz.ir` → `ns.dmbz.ir`.
   - This ensures public/ISP recursive resolvers forward Base32 tunnel chunks directly to `85.121.124.158:53` without requiring clients inside Iran to have direct UDP reachability to the VPS IP.

3. **AX3000T Client Integration:**
   - Standby binary: `/usr/local/bin/dnstt-client` (`aarch64`, Go 1.24 stripped).
   - Procd service: `/etc/init.d/dnstt` (disabled by default, manual/watchdog start).
   - Local socket: `127.0.0.1:5300` (SOCKS5 interface).
   - Sing-box integration: Dedicated outbound `dnstt-emergency` pointing to `127.0.0.1:5300`, exposed inside the `proxy-select` selector group.

4. **Redmi Note 9S Rooted Mobile Integration:**
   - Magisk `trustusercerts` module installed at `/data/adb/modules/trustusercerts/system/etc/security/cacerts/2fd38180.0` to permit zero-warning MITM Domain Fronting for offline-generated CAs.
   - Standby bundle under `/sdcard/Blackout-Prep/` containing `dnstt-client-arm64`, PattNG, Psiphon, Briar, NekoBox, and offline map/config archives.

## Verification & Validation Status (2026-09-29)

- **Authoritative Delegation**: Confirmed `ns.dmbz.ir` resolves to `85.121.124.158` (Cloudflare Grey Cloud DNS-only). Recursive TXT queries for `*.t.dmbz.ir` reach `85.121.124.158:53` across public resolvers (`1.1.1.1`, `8.8.8.8`, `4.2.2.4`).
- **Resolver Latency Benchmarking**:
  - `1.1.1.1:53`: 4.0 ms (Primary recommended)
  - `4.2.2.4:53`: 4.8 ms
  - `192.168.1.1:53`: 4.6 ms
  - `8.8.8.8:53`: 225.1 ms
- **End-to-End Tunnel & SOCKS5 Validation**:
  - Verified on Laptop (`dnstt-client-amd64`) and AX3000T (`/usr/local/bin/dnstt-client` + `/etc/init.d/dnstt`).
  - Outbound curl test (`curl -x socks5h://127.0.0.1:5300 http://ip-api.com/json`) succeeded: egress verified through Cloudflare WARP Frankfurt (`104.28.197.15`, AS13335).
  - Sing-box Clash API latency test via `http://127.0.0.1:9090/proxies/dnstt-emergency/delay`: **1144 ms**.
  - Procd supervision on AX3000T: active with auto-restart on smux idle-session timeout.

