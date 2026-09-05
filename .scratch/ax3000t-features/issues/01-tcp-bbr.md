# 01 — Kernel TCP BBR Congestion Control

**What to build:** Install `kmod-tcp-bbr` and configure `/etc/sysctl.d/bbr.conf` with `net.ipv4.tcp_congestion_control = bbr` and `net.core.default_qdisc = fq_codel`. Replaces legacy cubic with Google BBR to eliminate throughput collapse on jittery cellular MCI 5G links over the European VPS tunnel.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

## Implementation Details

- Target package: `kmod-tcp-bbr` (available in official OpenWrt 25.12.5 feed for kernel `6.12.94-r1`).
- Persistent configuration: `/etc/sysctl.d/15-bbr.conf`:
  ```ini
  net.core.default_qdisc = fq_codel
  net.ipv4.tcp_congestion_control = bbr
  ```
- Immediate activation via `sysctl -p /etc/sysctl.d/15-bbr.conf`.

## Verification Criteria

- [ ] `sysctl net.ipv4.tcp_available_congestion_control` returns `bbr cubic reno`.
- [ ] `sysctl net.ipv4.tcp_congestion_control` returns `bbr`.
- [ ] Router reboots cleanly and preserves `bbr` as default.
- [ ] Throughput to European VPS / YouTube maintains high bitrate without stalling.
- [ ] Footprint check: RAM overhead is 0 MB, overlay storage is <20 KB.
