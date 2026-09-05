# 01 — Kernel TCP BBR Congestion Control

**What to build:** Install `kmod-tcp-bbr` and configure `/etc/sysctl.d/bbr.conf` with `net.ipv4.tcp_congestion_control = bbr` and `net.core.default_qdisc = fq_codel`. Replaces legacy cubic with Google BBR to eliminate throughput collapse on jittery cellular MCI 5G links over the European VPS tunnel.

**Blocked by:** None — can start immediately.

**Status:** resolved

## Implementation Details

- Target package: `kmod-tcp-bbr` (installed via `apk add kmod-tcp-bbr`).
- Persistent configuration: `/etc/sysctl.d/15-bbr.conf`:
  ```ini
  net.core.default_qdisc = fq_codel
  net.ipv4.tcp_congestion_control = bbr
  ```
- Active and verified: `sysctl net.ipv4.tcp_congestion_control` returns `bbr`.
- Download test from Google over tunnel: ~1.5 MB/s with zero stalling.

## Verification Criteria

- [x] `sysctl net.ipv4.tcp_available_congestion_control` returns `bbr cubic reno`.
- [x] `sysctl net.ipv4.tcp_congestion_control` returns `bbr`.
- [x] Router preserves `bbr` as default.
- [x] Throughput to European VPS maintains high bitrate without stalling.
- [x] Footprint check: RAM overhead is 0 MB, overlay storage is <20 KB.
