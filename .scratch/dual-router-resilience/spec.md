# Dual-Router Resilience & Auto-Port Architecture — Design Specification

**Status:** Approved  
**Date:** 2026-09-04  
**Scope:** Xiaomi AX3000T (`192.168.1.1`, OpenWrt 25.12.5) & ZLT X28 (`192.168.70.1`, OpenWrt 19.07 vendor)

---

## 1. Problem Statement & Background

Historically, the two-router home network suffered from recurring outages after power cuts:
1. **Boot Race:** AX3000T boots in ~45s; X28 cellular modem takes ~150s to initialize baseband, camp on cell tower, and obtain bearer IP. When AX3000T booted first, WAN DHCP timed out, watchdogs failed, and repeated automatic reboots incremented bootcount counters until U-Boot entered recovery loops.
2. **Port Confusion:** The 4 physical ports on the AX3000T are all labeled "WAN/LAN" on the chassis. Hardcoding WAN to a specific port caused silent failures whenever cables were moved or plugged into a different port during living room relocation.
3. **Single Proxy Engine Failure:** All household devices depended on a single proxy instance on the thermal-stressed X28 modem.

---

## 2. Architecture & Roles

```
Internet (MCI 5G / Rightel)
        │
┌───────▼─────────────────────────────────────────────────┐
│ ZLT X28 (192.168.70.1) — Cellular WAN Edge & Standby VPN │
│  · Cellular modem (MCI 5G NSA)                          │
│  · Mihomo proxy engine (:1080 SOCKS, :12345 redirect)    │
│  · Fallback Wi-Fi: ZL-5G / ZL-2.4G                      │
│  · Telegram bot control plane & telemetry              │
└───────┬─────────────────────────────────────────────────┘
        │ Ethernet Cable (any port on X28 ──► any port on AX3000T)
┌───────▼─────────────────────────────────────────────────┐
│ Xiaomi AX3000T (192.168.1.1) — House Core & Primary VPN  │
│  · Auto-sensing WAN detection (plug into ANY port)      │
│  · Primary Wi-Fi 6: XI-5G / XI-2G (WPA2 xirouter123)    │
│  · Sing-box proxy engine (TUN / stack: system)          │
│    VLESS+Reality (:443) + Hysteria2 (:31800)            │
│    Domestic Iran (geosite-ir / geoip-ir) -> DIRECT     │
│    Foreign / Blocked -> VPS Tunnel                      │
│  · CAKE SQM on active WAN port (50M/15M)                │
│  · nlbwmon per-device usage accounting                  │
│  · ZERO automatic reboots (100% boot-order immune)      │
└─────────────────────────────────────────────────────────┘
```

### Role Summary:
- **X28:** Cellular WAN gateway + backup VPN on `ZL-5G`.
- **AX3000T:** Main household router + primary VPN on `XI-5G` + Wi-Fi 6 AP.
- **Independence:** Anyone in the house can connect to `XI-5G` or `ZL-5G`. Each has its own independent VPN connection to the VPS. If either box fails or is unplugged, the other continues operating without interruption.

---

## 3. Subsystem Detailed Designs

### 3.1. Auto-Sensing WAN Port (`wan-detector`)

The AX3000T features 4 physical ports managed as DSA net devices: `wan`, `lan2`, `lan3`, `lan4`.

#### Logic:
1. A lightweight procd service `/usr/sbin/wan-detector` listens to net hotplug events (`carrier 1`).
2. When link carrier rises on any candidate port (`wan`, `lan2`, `lan3`, `lan4`), it runs an ARP probe for `192.168.70.1` using `arping -I <port> -c 1 -w 1 192.168.70.1`.
3. If an ARP reply with MAC matching X28 (`98:a9:42:6b:67:b8`) is received on `<port>`:
   - That `<port>` is designated as the WAN device.
   - The remaining 3 ports are assigned as bridge members in `br-lan`.
   - If the current configuration already matches, no action is taken (idempotent).
   - If changed, UCI `network.wan.device` and `network.@device[0].ports` are updated and `ifup wan` is triggered without restarting the entire network or dropping LAN connections.
4. If no port sees the X28 (e.g. during early boot while X28 is booting), the service takes no destructive action; it leaves the existing port configuration untouched and retries when link events fire.

### 3.2. Power-Outage & Boot-Race Immunity

1. **Static WAN Configuration:**
   - IP: `192.168.70.2`
   - Netmask: `255.255.255.0`
   - Gateway: `192.168.70.1`
   - DNS: `192.168.70.1`
   - *Advantage:* Instantaneous packet flow as soon as PHY link powers up; no DHCP timeout or negotiation delay.
2. **Zero-Auto-Reboot Policy:**
   - No script or watchdog on the AX3000T is permitted to invoke `reboot` automatically upon connection failure.
   - If the upstream link or tunnel is down, services retry passively using standard exponential backoff.
3. **DNS State Safety:**
   - While offline, `dnsmasq` serves local hostnames and returns SERVFAIL/timeout for external queries.
   - Cache poisoning is prevented by exclusively forwarding to clean resolvers.

### 3.3. Sing-Box Proxy Engine on AX3000T

1. **Kernel Driver:**
   - `kmod-tun` (Linux TUN device driver, `/dev/net/tun`) installed via apk.
2. **Inbound Configuration:**
   - Type: `tun`
   - Interface name: `singtun`
   - Address: `172.19.0.1/30`
   - MTU: `1400`
   - Stack: `system` (pure Linux routing table rules via `ip rule` / policy routing table; zero netlink/nfqueue dependencies).
   - Auto-route: `true`
3. **Outbounds & Routing:**
   - `vps-reality`: VLESS + Reality over port 443 to `85.121.124.158` (`www.bing.com` SNI).
   - `hy2`: Hysteria2 over UDP port 31800 to `85.121.124.158` (`salamander` obfs).
   - `auto`: URL-test failover group between `vps-reality` and `hy2` testing `https://www.gstatic.com/generate_204`.
   - Rule-sets (compiled binary SRS format):
     - `geosite-ir` & `geoip-ir` -> `direct`
     - Private IP CIDRs (`192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`) -> `direct` (router management and local subnet traffic never hijacked)
     - `final` -> `auto` (VPS tunnel)
4. **X28 Passthrough Alignment:**
   - In `tproxy-enable.sh` on the X28, the AX3000T's WAN IP (`192.168.70.2`) is explicitly returned/bypassed so that already-tunneled traffic from AX3000T is never re-intercepted or double-proxied.

---

## 4. Verification & Testing Plan

1. **Auto-WAN Verification:**
   - Plug cable into port 1 (`wan`): confirm WAN link up, ping 192.168.70.1 OK.
   - Move cable to port 2 (`lan2`): confirm auto-detector detects X28, rebinds WAN to `lan2`, other 3 ports remain LAN.
   - Repeat for ports 3 and 4.
2. **Dual-VPN Isolation Test:**
   - Client A connects to `XI-5G`: verifies IP is VPS (`85.121.124.158`), YouTube works, Digikala is domestic latency (<20ms).
   - Client B connects to `ZL-5G`: verifies independent browsing via X28's Mihomo.
   - Stop sing-box on AX3000T: verify `ZL-5G` is completely unaffected.
3. **Power-Cut Simulation:**
   - Cut power to both devices simultaneously.
   - Power both on together.
   - Observe AX3000T finishes boot at T+45s; `XI-5G` broadcasts.
   - Observe X28 finishes boot at T+150s.
   - Verify that at T+160s, internet flows through `XI-5G` without human intervention, zero service crashes, zero reboots.

---

## 5. Rollback Plan

All configuration files and partition backups are persisted:
- Stock partition images: `C:\Users\Public\axtftp\backup\` (Factory, Nvram, Bdata, BL2, FIP, KF).
- Clean OpenWrt baseline snapshot: `C:\Users\Public\axtftp\backup\ax3000t-config-20260904.tar.gz`.
- Any issue during deployment is reversible via standard `sysupgrade -r` of the backup snapshot or by disabling the procd init script.
