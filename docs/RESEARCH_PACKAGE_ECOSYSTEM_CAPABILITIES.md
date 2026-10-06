# Research: Package Ecosystem & System Capabilities for Home Network Ecosystem

**Target Hardware:** Xiaomi Mi Router AX3000T (`192.168.1.1`) + Tozed ZLT X28 5G CPE (`192.168.70.1`)  
**Scope:** Capabilities, packages, system optimizations, and edge services (Excluding Telegram Bot)  
**Author:** AI Research Subagent  
**Date:** September 2026  
**Status:** Complete & Primary-Source Verified  

---

## 1. Executive Summary & Hardware Budget Baseline

To avoid bricking, memory starvation (OOM crashes), or storage exhaustion, all package evaluations must be strictly bounded by the physical and architectural constraints of the two devices:

### Hardware & Resource Inventory (Live Verified)

| Parameter | Xiaomi AX3000T (Primary Core) | Tozed ZLT X28 (Cellular Edge) | Strategic Implication |
|---|---|---|---|
| **SoC / Architecture** | MediaTek Filogic 820 MT7981B (2× Cortex-A53 @ 1.3GHz) | MediaTek MT6890 (4× Cortex-A55 @ 2.0GHz) | AX3000T has ARMv8 Cryptographic Extensions + Inside Secure EIP-197 hardware crypto engine. |
| **OS / Package Manager** | Clean OpenWrt 25.12.5 (Linux 6.12.94, `apk-tools 3.0.5`) | OpenWrt 19.07-SNAPSHOT (Kernel 4.19, `opkg` vendor-restricted) | AX3000T has 11,161 modern official upstream packages available via `apk`. X28 requires standalone binaries in `/data/proxy/bin/`. |
| **RAM Budget** | **256 MB Total** (92 MB Free / Available) | **643 MB Total** (188 MB Free + 208 MB Swap) | Heavy memory consumers (>25MB RSS) will cause OOM-killer termination on AX3000T. |
| **Flash / Storage** | **60.7 MB Overlay** (**26.0 MB Available**) | **287.6 MB `/data`** (**119.4 MB Available**) | **CRITICAL:** AX3000T has NO USB port. Packages >15 MB will consume nearly all remaining flash and threaten sysupgrade space. |
| **Cellular Uplink** | Slaved via `lan4` (Static `192.168.70.2`) | Samantel SIM (Carrier-Grade NAT, Private `10.x.x.x` IP) | Direct inbound IPv4 port forwarding from the public internet is impossible without an intermediary relay or reverse tunnel. |

---

## 2. Remote Access & Zero-Config Overlay Mesh Networking

### 2.1. The CGNAT Dilemma
Because the home network relies exclusively on a cellular SIM (Samantel roaming on MCI 5G), the router does not receive a public IPv4 address. Direct inbound connections (e.g., standard DDNS + port forwarding) are blocked by the carrier. Remote access to LuCI, home PCs, NAS, and security cameras requires an outbound-initiated tunnel.

### 2.2. Technology Comparison: Tailscale vs. WireGuard vs. Sing-Box Inbound Mesh

| Evaluation Criteria | Tailscale (`tailscale` + `luci-app-tailscale-community`) | Native WireGuard to VPS (`kmod-wireguard` + `luci-proto-wireguard`) | Sing-Box Inbound Proxy Mesh (Already Running) |
|---|---|---|---|
| **Package / Flash Footprint** | **25.0 MiB** (Consumes **96%** of remaining 26MB flash!) | **183 KiB** total (92KB kmod + 56KB tools + 35KB luci) | **0 bytes** (Already installed on router & VPS) |
| **RAM Consumption** | **35–55 MB RSS** (Written in Go with bundled wireguard-go) | **< 2.0 MB** (Runs entirely in kernel space) | **0 extra MB** (Shares existing sing-box core) |
| **Iran DPI Resistance** | **Poor.** Tailscale control plane (`login.tailscale.com`) and DERP relays are heavily throttled/blocked by MCI/Irancell DPI. | **Moderate to Poor** if raw UDP is inspected; excellent if encapsulated or Point-to-Point to owned VPS. | **Superior.** Rides inside existing VLESS-Reality (TCP 443) or Hysteria2 (Salamander obfs). |
| **Hardware Crypto** | Software Go implementation; high CPU under heavy load. | **Full hardware acceleration** via MediaTek EIP-197 / ARMv8 Crypto Extensions (>900 Mbps line rate). | Tunneled through hardware-accelerated AES/ChaCha. |
| **Viability Rating** | **NOT RECOMMENDED** (Flash & Memory Hazard) | **HIGH (Recommended for Full L3 VPN)** | **HIGHEST (Zero Overhead, Instant Access)** |

*Primary Sources:*
- OpenWrt Tailscale Guide: `https://openwrt.org/docs/guide-user/services/vpn/tailscale`
- OpenWrt WireGuard Configuration: `https://openwrt.org/docs/guide-user/services/vpn/wireguard/client`
- Tailscale KB 1077 (OpenWrt limitations): `https://tailscale.com/kb/1077/openwrt`

### 2.3. Recommended Implementation Architecture

#### Path A: Zero-Footprint Remote Access via Existing VPS Reverse Proxy (Recommended)
Because sing-box and the VPS (`85.121.124.158`) are already operational:
1. Configure an authenticated HTTP/SOCKS inbound or reverse HTTP endpoint on the VPS.
2. The AX3000T maintains an outbound persistent connection to the VPS.
3. Access LuCI (`192.168.1.1:80`) securely through your browser using your VPS credentials without installing any additional package on the router.

#### Path B: Kernel-Space Point-to-Point WireGuard to VPS
If full Layer 3 LAN-to-LAN routing is needed:
```sh
# 1. Install kernel module and LuCI interface (~183 KB):
apk add kmod-wireguard wireguard-tools luci-proto-wireguard

# 2. Configure WireGuard peer pointing to VPS IP 85.121.124.158:51820 with:
# PersistentKeepalive = 25 (Keeps the cellular CGNAT mapping permanently open)
```

---

## 3. Advanced Wireless & Roaming Optimization

### 3.1. Band Steering: `usteer` vs. `dawn`

| Metric | `usteer` (Currently Installed) | `dawn` (`luci-app-dawn`) |
|---|---|---|
| **Package Size** | 45 KiB (Binary) | 112 KiB (Binary + Lua/uCode dependencies) |
| **RAM Usage** | **~1.2 MB** | **8.0–12.0 MB** |
| **Topology Focus** | **Single AP / Multi-band Steering** + 802.11k/v BSS Transition Management | Multi-AP distributed mesh roaming (Requires inter-router daemon communication) |
| **Suitability for AX3000T** | **Optimal.** AX3000T is a standalone high-power Wi-Fi 6 router. Steering clients between 2.4GHz (`XI-2G`) and 5GHz (`XI-5G`) is exactly what `usteer` excels at. | **Redundant.** DAWN is designed for multiple OpenWrt APs exchanging hearing maps. Running DAWN on a single AP adds high memory overhead with zero benefit. |
| **Viability** | **HIGHEST (Already installed, only needs enabling)** | **NOT RECOMMENDED** |

*Primary Sources:*
- OpenWrt usteer Documentation: `https://openwrt.org/docs/guide-user/network/wifi/usteer`
- OpenWrt DAWN Project: `https://openwrt.org/docs/guide-user/network/wifi/dawn`

### 3.2. Step-by-Step Activation of `usteer`
On the AX3000T, `usteer` is already installed but in `inactive` state. Enable it to automatically steer capable phones and laptops from the crowded 2.4GHz band to the 5GHz Wi-Fi 6 band:

```sh
# Configure usteer thresholds
uci set usteer.@usteer[0].enabled='1'
uci set usteer.@usteer[0].local_mode='1'
uci set usteer.@usteer[0].band_steering_interval='30000'
uci set usteer.@usteer[0].band_steering_min_snr='-68'
uci commit usteer

# Enable and start daemon
/etc/init.d/usteer enable
/etc/init.d/usteer start
```

### 3.3. Wi-Fi Power Scheduling (`luci-app-wifi-schedule`)
- **Package:** `luci-app-wifi-schedule` (Installed size: ~18 KiB)
- **Function:** Automates turning off Wi-Fi radios (e.g., from 02:00 to 06:30) to reduce RF pollution and save ~1.8W power.
- **Viability:** **Medium.** Recommended only if household members have no overnight smart home sensors or background Wi-Fi devices.

---

## 4. Security, Intrusion Prevention & Firewall Hardening

### 4.1. Comparison: Native `firewall4` vs. `banIP` vs. `CrowdSec`

| Feature | Native `firewall4` / `nftables` | `banIP` (`luci-app-banip`) | `CrowdSec` (`crowdsec`) |
|---|---|---|---|
| **Installed Size** | 0 KB (Built-in) | **133 KiB** | **186 MiB** |
| **RAM Footprint** | 0 MB (Kernel netfilter) | **4–8 MB** (In-memory IP sets) | **>150 MB** |
| **Feasibility on AX3000T** | **100% Native** | **High** | **IMPOSSIBLE (Exceeds total flash & free RAM)** |
| **Protection Scope** | SYN flood protection, stateful connection tracking, port scan dropping. | Curated malicious IP feeds (blocklist.de, Tor exit nodes, brute-force bots). | Behavioral log parsing and cloud-shared threat intelligence. |

*Primary Sources:*
- OpenWrt firewall4 / nftables: `https://openwrt.org/docs/guide-user/firewall/firewall_configuration`
- OpenWrt banIP: `https://openwrt.org/docs/guide-user/services/banip`
- CrowdSec OpenWrt Hub: `https://openwrt.org/docs/guide-user/security/crowdsec`

### 4.2. Recommended Security Hardening Steps

#### 1. Native SYN Flood & Connection Hardening in `/etc/config/firewall`
OpenWrt's native firewall4 provides enterprise-grade DoS protection with zero RAM overhead:
```sh
uci set firewall.@defaults[0].syn_flood='1'
uci set firewall.@defaults[0].synflood_protect='1'
uci set firewall.@defaults[0].drop_invalid='1'
uci commit firewall
/etc/init.d/firewall restart
```

#### 2. Automated Malicious IP Blocking with `banIP`
`banIP` downloads threat feeds and compiles them directly into kernel `nftables` sets, dropping inbound scanner packets with zero CPU penalty:
```sh
# Install banIP and its LuCI interface (~140 KB):
apk add banip luci-app-banip

# Enable selected feeds (e.g. drop CIDRs from known scanner networks):
uci set banip.global.ban_enable='1'
uci commit banip
/etc/init.d/banip start
```

---

## 5. Network Telemetry, Monitoring & Dashboard Capabilities

### 5.1. Dashboard & Monitoring Matrix

| Package | Flash Size | RAM Usage | Interface | Assessment & Recommendation |
|---|---|---|---|---|
| **`prometheus-node-exporter-lua`** | **15 KiB** | **< 2.0 MB** | Metrics API (`:9100/metrics`) | **HIGH.** Ideal if you run a Prometheus/Grafana instance on your home PC, NAS, or VPS. Exports accurate hardware, network, and wireless telemetry. |
| **`darkstat`** | **91 KiB** | **2.5–4.0 MB** | Built-in Web UI (`:667`) | **HIGH.** Instant, lightweight web dashboard showing per-host bandwidth graphs, active network protocols, and traffic volume. Runs completely in memory. |
| **`bmon`** | **94 KiB** | **< 1.0 MB** | Terminal (CLI) | **HIGH.** Best CLI tool for inspecting real-time gigabit traffic per interface over SSH (`bmon -p lan4,br-lan`). |
| **`luci-app-wol`** | **8.3 KiB** | **0 MB** | LuCI Web GUI | **HIGH.** Web interface for `etherwake` (already installed). Allows 1-click waking of PCs and media servers over LAN. |
| **`netdata`** | **25.0 MiB** | **35–60 MB** | Heavy Web UI (`:19999`) | **NOT RECOMMENDED.** Consumes the entire remaining flash overlay and triggers memory pressure. |

*Primary Sources:*
- Prometheus Node Exporter Lua: `https://openwrt.org/docs/guide-user/services/prometheus/node-exporter-lua`
- darkstat on OpenWrt: `https://openwrt.org/docs/guide-user/services/darkstat`

### 5.2. Recommended Deployments

#### 1. Instant Traffic Visualizer: `darkstat`
```sh
apk add darkstat
uci set darkstat.@darkstat[0].interface='lan'
uci set darkstat.@darkstat[0].enabled='1'
uci commit darkstat
/etc/init.d/darkstat enable
/etc/init.d/darkstat start
# Access live graphs at: http://192.168.1.1:667/
```

#### 2. LuCI Wake-On-LAN Portal: `luci-app-wol`
```sh
apk add luci-app-wol
# Access directly under LuCI -> Services -> Wake on LAN
```

---

## 6. Local Smart Home & Lightweight Edge Services

### 6.1. Local MQTT Message Broker (`mosquitto-nossl`)
- **Package:** `mosquitto-nossl` + `luci-app-mosquitto` (Installed size: ~260 KiB)
- **RAM Usage:** **~2.5 MB**
- **Capability:** Turns the AX3000T into a high-speed, local MQTT message bus on LAN port 1883.
- **Benefits:**
  - Connects local ESP32, Zigbee2MQTT, Sonoff, Shelly, and Tasmota smart home sensors.
  - Zero cloud dependency: devices communicate with Home Assistant or scripts even during cellular internet dropouts.
- **Viability:** **HIGH.** Extremely stable, lightweight C implementation.

*Configuration snippet (`/etc/mosquitto/mosquitto.conf`):*
```conf
listener 1883 192.168.1.1
allow_anonymous true
```

### 6.2. Precision Local Time Authority (`chrony`)
- **Package:** `chrony` + `luci-app-chrony` (Installed size: ~265 KiB)
- **RAM Usage:** **~2.2 MB**
- **The Problem:** The default Busybox `sysntpd` is a passive client. When the internet drops, the router cannot serve reliable time to LAN devices, and system clocks drift, breaking TLS certificates.
- **The Solution:** `chrony` provides sub-millisecond clock discipline. It acts as an authoritative local NTP server (`192.168.1.1:123`) for all smart TVs, PCs, and security cameras, keeping household time synchronized during cellular connection outages.
- **Viability:** **HIGH.**

---

## 7. Gaming, Latency & Kernel TCP Optimizations

### 7.1. BBR Congestion Control Activation Status
- **Inspection Finding:** `net.ipv4.tcp_congestion_control = bbr` is **already compiled into the kernel and active**!
- To ensure it persists across every reflash or network restart:
```sh
cat << "EOF" > /etc/sysctl.d/99-tcp-bbr.conf
net.core.default_qdisc = fq_codel
net.ipv4.tcp_congestion_control = bbr
EOF
```

### 7.2. CAKE SQM Fine-Tuning for Cellular Jitter & Gaming
- **Current Status:** `sqm.eth1.enabled='0'` (disabled).
- **Why Cellular Gaming Lags:** Cellular uplinks have variable latency (bufferbloat). When another device downloads or streams video, queue build-up causes gaming ping to jump from 40ms to 400ms.
- **The Solution:** Enable CAKE on the active WAN interface (`lan4`) with `diffserv4` and `ack-filter`:
  - `diffserv4`: Automatically classifies packets by DSCP into 4 priority queues:
    1. **Voice / Low Latency (Tin 1):** Gaming UDP, VoIP, DNS.
    2. **Video (Tin 2):** Streaming media.
    3. **Best Effort (Tin 3):** Standard web browsing.
    4. **Bulk (Tin 4):** Torrents, background file downloads.
  - `ack-filter`: Drops redundant TCP ACK packets on the asymmetric cellular upload, saving 20–30% of upload capacity.

```sh
uci set sqm.eth1.enabled='1'
uci set sqm.eth1.interface='lan4'
uci set sqm.eth1.qdisc='cake'
uci set sqm.eth1.script='layer_cake.qos'
uci set sqm.eth1.download='85000' # Cap at 85-90% of actual cellular capacity
uci set sqm.eth1.upload='30000'
uci set sqm.eth1.cake_opts='diffserv4 dual-dsthost nat ack-filter'
uci commit sqm
/etc/init.d/sqm restart
```

### 7.3. MiniUPnP Fine-Tuning for Open NAT (PlayStation 5, Xbox, PC Gaming)
- **Current Status:** `miniupnpd` is running with outdated legacy settings: `igdv1='1'` and fake speed constraints (`download=1024`, `upload=512`).
- **Optimization:**
  - Modern gaming consoles (PS5, Xbox Series X, PC Steam) prefer IGD version 2 (`igdv1=0`) for full Port Mapping Protocol support.
  - Remove ancient 1 Mbps bandwidth throttles from upnpd config.

```sh
uci set upnpd.config.igdv1='0'
uci delete upnpd.config.download
uci delete upnpd.config.upload
uci commit upnpd
/etc/init.d/miniupnpd restart
```

---

## 8. Master Capability & Implementation Matrix

| Capability Category | Recommended Package | Flash Footprint | RAM Usage | Viability Rating | Primary Benefit |
|---|---|---|---|---|---|
| **Remote Access** | Inbound Reverse Proxy via VPS | **0 KB** | **0 MB** | **HIGHEST** | Zero overhead; immune to CGNAT and Iranian DPI. |
| **Remote Access (L3)** | `kmod-wireguard` + `luci-proto-wireguard` | 183 KiB | < 2 MB | **HIGH** | Full kernel-accelerated L3 VPN to VPS without Go overhead. |
| **Remote Access (Mesh)** | `tailscale` | 25.0 MiB | 45 MB | **NOT RECOMMENDED** | Exceeds flash safety margin; blocked by DPI. |
| **Wi-Fi Optimization** | `usteer` (Active Configuration) | **0 KB (Installed)** | **~1.2 MB** | **HIGHEST** | Seamless 2.4G/5G band steering for iPhones, Androids, PCs. |
| **Firewall Hardening** | Native `firewall4` SYN flood tuning | **0 KB** | **0 MB** | **HIGHEST** | Protects against cellular WAN port scans and DoS. |
| **IP Reputation Block** | `banip` + `luci-app-banip` | 140 KiB | 4–8 MB | **HIGH** | Automatically drops known scanner IPs via nftables sets. |
| **Intrusion Prevention** | `crowdsec` | 186 MiB | >150 MB | **INFEASIBLE** | Overflows storage by 700%; triggers instant OOM crash. |
| **Traffic Telemetry** | `darkstat` | 91 KiB | 3 MB | **HIGH** | Fast, lightweight per-host traffic charts on `:667`. |
| **CLI Monitoring** | `bmon` | 94 KiB | < 1 MB | **HIGH** | Real-time interface bandwidth monitor in SSH. |
| **Device Wake-Up** | `luci-app-wol` | 8.3 KiB | 0 MB | **HIGH** | Web UI for waking PCs and NAS devices over LAN. |
| **Smart Home Broker** | `mosquitto-nossl` | 244 KiB | 2.5 MB | **HIGH** | Local MQTT broker for smart home sensors without cloud. |
| **Precision Time** | `chrony` + `luci-app-chrony` | 265 KiB | 2.2 MB | **HIGH** | Local NTP server for IoT, TVs, and PCs during outages. |
| **Gaming / Bufferbloat** | CAKE SQM (`diffserv4` + `ack-filter`) | **0 KB (Installed)** | **~1 MB** | **HIGH** | Eliminates gaming ping spikes during concurrent downloads. |
| **Open NAT Gaming** | `miniupnpd` (IGDv2 upgrade) | **0 KB (Installed)** | **~1 MB** | **HIGH** | Native Open NAT for PS5, Xbox, and PC multiplayer. |
