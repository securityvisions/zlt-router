# X28 Smart Edge — spec

Make the ZLT X28 a load-bearing network edge instead of a plain modem, and
integrate it with the existing home-network system (AX3000T, VPS s-ui, Xirouter
app, Telegram bot).

## Context

The X28 (`192.168.70.1`) is the cellular WAN device the whole home network rides
on (Samantel SIM, camping on MCI 5G NSA at this location). It was unlocked
(root shell via the 1.5.13 DMZ injection) and carries v2rayA + xray-core. The
AX3000T (`192.168.1.1`) is the main router: PassWall proxy split-routing, DNS
ad-blocking, SQM, nlbwmon billing, Samantel balance, Telegram bot, Router API,
Xirouter app. The VPS (`85.121.124.158`) runs s-ui (sing-box): VLESS+REALITY
:443, Hysteria2 :31800, subscription :2096.

### Verified facts (2026-08-15)

- X28 hardware: 4× Cortex-A55 @ 2 GHz, 643 MB RAM, MediaTek hw_nat active.
- AX3000T hardware: 2× Cortex-A53 @ 1 GHz, 239 MB RAM (≈75 MB free).
- MCI (432-11) registers on 5G NSA (RSRP −77/−92); direct ≈45–65 Mbps,
  proxied ≈21 Mbps, vs Rightel 4G ≈0.5 Mbps. MCI is the preferred operator.
- The X28's vendor `lan_mgr` overrides uci — treat the X28's own routing as
  fixed; bolt features on top.
- Single SIM slot only. Plain WireGuard is unreliable in Iran — remote access
  uses REALITY/Hysteria2 + (planned) Cloudflare Tunnel.

### Reversal

`.scratch/network-resilience-enhancements/spec.md` evaluated the X28 for
load-balancing and found it counterproductive. This effort supersedes that for
the *smart-edge* role: the X28 is not load-balanced; it is the single link that
gets made sticky, monitored, hardened, and used as a second proxy engine.

## Tickets

1. X28 link-state reader (the seam)
2. X28 management hardening
3. MCI stickiness watchdog
4. X28 proxy crypto engine (SOCKS → VPS)
5. PassWall "via-X28" node + failover chain
6. Link card in bot + Router API + Xirouter app
7. SQM re-tune to the MCI link
8. Cloudflare Tunnel for remote app access
9. Nightly config backups
10. Speed-test scheduler + trend + degradation alert
11. X28 backup/guest network (v2rayA on X28 LAN)
12. X28 as primary proxy edge with split routing (Stage 2)
13. VPS health checks + auto-recovery

Implemented so far: 1–4 (resolved), 5 partial (node live, failover chain open).
