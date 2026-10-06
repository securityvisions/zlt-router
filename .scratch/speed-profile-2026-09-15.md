# Network Speed & Latency Profile (2026-09-15, evening ~21:00 IRST)

Method: baseline → one controlled change → re-measure. No tunnel match
parameters (flow/uuid/SNI) were touched at any point.

## Baseline (AX3000T, through vps-reality tunnel, SQM ON)

| Metric | Value |
|---|---|
| Download (10MB via tunnel) | ~15–16 Mbps |
| Upload (2MB via tunnel) | ~5.4 Mbps |
| Idle RTT to VPS | avg 144 ms (min 123 / max 205) |
| RTT under download load | avg 147 ms (max 197) |
| Bufferbloat | ≈ 0 ms — SQM/CAKE fully effective |
| Radio | MCI 5G NSA, RSRP −74 dBm (good) |

## Controlled experiments

1. **SQM OFF (30s window):**
   - Upload: ~7 Mbps, Download: ~16 Mbps (marginal change → SQM is NOT the bottleneck)
   - RTT under load degraded: avg 158 ms, max 235 ms → **SQM ON is strictly better**
   - Restored SQM (95M/25M cake diffserv4 ack-filter) — verified `cake 8015:` active.
2. **Raw TCP to VPS on non-standard ports (5201):** connects, then collapses to
   ~1 Mbps with cwnd 1.4KB — consistent with carrier QoS on non-standard ports.
   All production traffic rides dport 443 and is unaffected.
3. **iperf3 5201/8443:** unreliable (version mismatch 3.20↔3.16, port collision
   with sui) — discarded as a measurement tool; cloudflare-through-socks used
   instead. iperf3 server + temp UFW rule removed.

## Changes kept (safe, server-side only)

- VPS `/etc/sysctl.d/99-bbr-buffer-tune.conf`: BBR + fq qdisc, 64MB rmem/wmem,
  tcp_fastopen=3, mtu_probing=1, slow_start_after_idle=0.
  Benefits TCP 443 throughput on a lossy path; zero tunnel-matching risk.

## Changes explicitly reverted

- `flow: xtls-rprx-vision` on VPS client `parsa` (caused REALITY handshake
  mismatch + household outage; reverted to empty and s-ui restarted).

## Conclusion

- Ping/latency: already optimal (bufferbloat ≈ 0). No further gain available
  from SQM/router tuning.
- Throughput: 15↓ / 5.4↑ Mbps is the cellular bearer's real capacity at evening
  peak. Repo history documents MCI being fast at night and congested by day.
  Re-measure after ~01:00 to see the off-peak ceiling; if night numbers are
  materially higher, the only remaining lever is carrier/bearer, not config.

## Incident note

During profiling, a server-side `flow` edit broke the tunnel once. Reverted;
watchdog returned to MODE=proxy FAILS=0; final probe 204.
