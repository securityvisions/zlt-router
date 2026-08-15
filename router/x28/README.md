# X28 smart-edge subsystem

The ZLT X28 (`192.168.70.1`) is the cellular WAN device the home network rides
on (Samantel SIM, MCI 5G NSA). These scripts turn it from a plain modem into a
smart edge while keeping the AX3000T as the policy/DNS/monitoring brain.

## Deployed layout

| Repo file | Device | Path | Role |
|---|---|---|---|
| `x28/linkstate.sh` | X28 | `/data/proxy/linkstate.sh` | live link-state reader |
| `x28/linkstate.sh` | AX3000T | `/root/x28link.sh` | same reader, talks to the X28 HTTP API |
| `x28/reselect.sh` | AX3000T | `/root/x28reselect.sh` | re-selects the preferred operator |
| `x28/harden.sh` | X28 | `/data/proxy/harden.sh` | management firewall (boot via rc.local) |
| `x28/x28lib.sh` | both | `/data/proxy` + `/root` | shared API helpers (session, sha256, field extractor) |
| `x28watch.sh` | AX3000T | `/root/x28watch.sh` | stickiness + degradation watchdog (cron */5) |
| `x28/xray-proxy.json` | X28 | `/data/proxy/sing-box/xray-proxy.json` | xray-core crypto-engine config (template above) |
| `x28/x28proxy.init` | X28 | `/etc/init.d/x28proxy` | procd service running the crypto engine (START=98) |
| `x28/passwall-via-x28.sh` | AX3000T | `/root/passwall-via-x28.sh` | ensure the PassWall via_x28 node exists |
| `x28/deploy.sh` | repo | — | push the whole subsystem to both routers |
| `x28/tproxy-enable.sh` / `tproxy-disable.sh` | X28 | `/data/proxy/` | **opt-in** transparent proxy for the backup/guest network (excludes the AX3000T) |
| `x28/split-proxy.json`, `stage2-enable.sh` / `stage2-disable.sh` | X28 | `/data/proxy/` | **opt-in** Stage-2: X28 as primary proxy edge with domestic/international split |

## How it fits together

```
              X28 (192.168.70.1)                     AX3000T (192.168.1.1)
              ─────────────────                     ─────────────────────
 modem/5G ──► br0 ──► SOCKS :1080 (xray-core) ◄──── PassWall node "via_x28"
   │        (xray → VPS REALITY/WS)                    (available, switchable)
   └── linkstate.sh ◄────────────── HTTP ─────────── x28link.sh (cron watchdog)
```

- **Link stickiness**: `x28watch.sh` (cron */5) reads the link, alerts on
  operator drift/degradation and calls `x28reselect.sh` to force MCI (43211).
- **Crypto engine**: the X28's xray-core terminates VLESS+REALITY to the VPS
  and exposes a SOCKS inbound on `192.168.70.1:1080`. PassWall's `via_x28`
  node points there — switching PassWall to it offloads the tunnel crypto from
  the AX3000T to the X28's 4× A55.
- **Hardening**: `harden.sh` drops management ports 22/23/2017 from outside the
  LAN (applied at boot from rc.local).

## Secrets

The real `xray-proxy.json` contains the VLESS UUID, REALITY public key and
short-id. They are client credentials and are **not** committed here — replace
the `__PLACEHOLDER__`s on the device from the s-ui panel, keep the file
root-only (`chmod 600 /data/proxy/sing-box/xray-proxy.json`).

## Operations

```sh
# link state, on demand (any device with LAN access)
/root/x28link.sh

# watchdog decision only (pure; used by tests too)
/root/x28watch.sh --check "<operator>" "<tech>" "<rsrp>" "<rsrp_5g>"

# switch PassWall to the X28 crypto engine and back
uci set passwall.@global[0].tcp_node='via_x28'; uci commit passwall; /etc/init.d/passwall restart
uci set passwall.@global[0].tcp_node='cdn_ws';    uci commit passwall; /etc/init.d/passwall restart

# crypto engine status on the X28
/etc/init.d/x28proxy status
```

The full failover chain (REALITY → Hysteria2 → via-X28 → direct) is the planned
extension of the existing fail-open/autorecover watchdogs; the node infrastructure
(`via_x28`) is already in place.
