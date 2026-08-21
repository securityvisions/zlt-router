# X28 Brain Promotion — spec

Permanently promote the ZLT X28 from WAN appliance to the home network's
brain: monitoring, alerting, remote control, DNS ad-blocking, Samantel
balance, per-device usage/billing, and the Router API + Xirouter app —
the functions the AX3000T carried before it died.

## Context

The AX3000T (`192.168.1.1`, the previous brain) hard-crash-loops and is
stuck on booting; recovery needs a UART → u-boot → TFTP reflashing that is
blocked on a 3.3 V USB-TTL adapter. The X28 (`192.168.70.1`) is the sole
WAN path and already carries, live and stable: the transparent proxy
(xray tproxy + SOCKS), the DNS chain (dnsmasq → xray forwarder → VPS →
8.8.8.8, defeating ISP DNS poisoning), and the operator failover watchdog
(MCI ↔ Rightel, proven both directions).

User decision: the promotion is **permanent** — the X28 stays the brain
even after the AX3000T is recovered (the AX3000T returns as an AP /
secondary, not as the brain).

This builds on the delivered parts of `.scratch/x28-smart-edge/spec.md`
(link reader, watchdog, crypto engine, primary proxy edge = Stage 2 tproxy).

### Verified facts (2026-08-20)

- X28 healthy: 4× Cortex-A55, ~200 MB RAM available, 157 MB free on
  `/data`, xray + v2raya + x28-watchdog running.
- AX3000T `192.168.1.1` unreachable (ping 100 % loss).
- `opkg update` downloads from the 19.07 snapshot feeds; `curl` and `ipset`
  installed; `jq`, `nlbwmon` missing.
- The vendor `lan_mgr` regenerates the dnsmasq config; the DNS chain rides
  on a `server=127.0.0.1#5353` upstream line that must survive everything
  we do.
- No uhttpd daemon runs on the X28; no cron — new services use procd.

## Hard safety rules (bind every ticket)

1. **Never** replace the vendor dnsmasq or disrupt the vendor web panel.
2. **Never** use the PLMN lock (the modem command that previously broke
   the X28's boot). Operator changes go only through the proven operator
   re-select path.
3. Ticket 01's rollback snapshot gates every other ticket; every deploy
   ticket runs the ticket-02 health gate **before and after** and stops on
   red.
4. Canonical copies live in the repo (`router/x28/`) with deploy-script
   wiring; never edit on the router directly. No secrets in the repo —
   tokens live in root-only configs on the X28.
5. All new services are procd-managed (respawn + boot-enabled); no cron.
6. DNS changes go through the established full-restart + hotplug-reapply
   pattern (a SIGHUP is not sufficient on this box).
7. Highest-risk additions (nlbwmon) soak for 24 h before their ticket
   closes, with a proven clean rollback.

## Prerequisites (human-gated, not ticket blockers)

- A Telegram bot token + chat ID for the new X28 bot (ticket 03).
- The Samantel credential/token for read-only balance queries (ticket 06).

## Tickets

1. Rollback snapshot + restore drill
2. Dependency install + `x28-health` gate
3. Status collector + Telegram alerts
4. Telegram remote control
5. DNS ad-blocking
6. Samantel balance on the X28
7. Per-device usage + Toman billing
8. Router API re-host + Xirouter app
9. Persistence, reboot proof + docs promotion
10. Fail-open network path (dead VPS must not take the house down)
11. mihomo proxy engine with automatic node failover

Edges: 01 → 02 → 03 → {04, 05, 06, 07} → 08 → 09
(05 also hangs off 02; 08 needs 03+06+07; 09 needs all deploy tickets;
10 and 11 hang off 02 and are resolved).
