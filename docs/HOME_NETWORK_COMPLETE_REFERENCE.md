# Home Network Architecture & Operations Manual — Complete Zero-to-One Reference

**Last Updated:** September 21, 2026  
**Hardware Ecosystem:** Xiaomi Mi Router AX3000T (`192.168.1.1`) + ZLT X28 5G CPE (`192.168.70.1`) + Remote Primary VPS (`85.121.124.158`) + Redundant VPS (`5.175.234.113`)

---

## 1. Executive Summary & Top-Level Topology

The home network is a dual-router cellular and VPN appliance built to survive power cuts, cable swapping, and regional censorship/DNS poisoning without requiring manual intervention.

```
                         Internet (MCI 5G NSA / Rightel 4G)
                                         │
┌────────────────────────────────────────▼────────────────────────────────────────┐
│  ZLT X28 (192.168.70.1) — Cellular Edge, Control Plane & Standby Gateway        │
│  · MediaTek MT6890 5G CPE (4× A55, 643 MB RAM), OpenWrt 19.07-SNAPSHOT          │
│  · Samantel SIM (PLMN 43211 MCI 5G NSA, fallback 43220 Rightel)                │
│  · Mihomo Proxy Engine (SOCKS :1080, Redirect :12345, Clash API :9090)         │
│  · Standalone Backup Wi-Fi: ZL-5G / ZL-2.4G                                    │
│  · Telegram Bot (@xirouterbot) + Web Dashboard (:8080)                         │
│  · Automation Loops: operator watchdog, balance monitor, VPS auto-heal         │
│  · DNS: dnsmasq (:53) ──► clean DoH (:5353) [Poisoned ISP DNS blocked]        │
└────────────────────────────────────────┬────────────────────────────────────────┘
                                         │ Single Ethernet Cable (ANY port to ANY port)
┌────────────────────────────────────────▼────────────────────────────────────────┐
│  Xiaomi AX3000T (192.168.1.1) — Primary House Router & Dedicated Proxy Core    │
│  · MediaTek Filogic 820 MT7981B (2× A53, 256 MB RAM)                           │
│  · Clean OpenWrt 25.12.5 Mainline (Linux 6.12.94, apk package manager)          │
│  · Auto-sensing WAN detection (wan-detector: auto-binds whichever port has X28) │
│  · Primary High-Performance Wi-Fi 6: XI-5G & XI-2G (WPA2/WPA3: xirouter123)    │
│  · Sing-Box Proxy Core (Redirect :12345, Tproxy :12346, SOCKS :1080, API :9090)│
│  · Transparent nftables interception for all LAN / Wi-Fi clients (/etc/axproxy)│
│  · Domestic Iran split-routing (geosite-ir, geoip-ir -> DIRECT)                │
│  · CAKE SQM on active WAN port (50 Mbps down / 15 Mbps up)                      │
│  · U-Boot Bootcount Guard (/etc/init.d/bootcount: zero bricking risk)           │
│  · ZERO automatic reboots (100% immune to power outages & boot order races)     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Master Credentials & Network Map (Vault)

### 2.1. Primary House Router — Xiaomi AX3000T

| Parameter | Value | Notes |
|---|---|---|
| **Hardware / Model** | Xiaomi AX3000T (RD03, MT7981B, 256 MB DDR3) | Chinese retail version |
| **Operating System** | OpenWrt 25.12.5 (r33051-f5dae5ece4) | Clean mainline, apk package manager |
| **LAN IP Address** | `192.168.1.1` (Subnet: `255.255.255.0`) | Gateway for house clients |
| **DHCP Server Range** | `192.168.1.100` – `192.168.1.249` (Lease: 12h) | Serves wired LAN & Wi-Fi clients |
| **SSH Access** | `ssh root@192.168.1.1` (Port 22) | Dropbear SSH daemon |
| **Root / Admin Password** | `xirouter123` | Used for SSH and LuCI Web UI |
| **LuCI Web Admin** | `http://192.168.1.1/` (Port 80 / 443) | uhttpd web server |
| **Wi-Fi 5GHz (Wi-Fi 6)** | SSID: **`XI-5G`** (Channel 36, 80 MHz, HE80) | WPA2/WPA3-SAE mixed: `xirouter123` |
| **Wi-Fi 2.4GHz** | SSID: **`XI-2G`** (Channel 1, 20 MHz, HE20) | WPA2/WPA3-SAE mixed: `xirouter123` |
| **Guest Wi-Fi** | SSID: **`XI-Guest`** (Isolate: enabled) | WPA2-PSK: `xiguest123` (Subnet: `192.168.3.1/24`) |
| **WAN Uplink Mode** | Static: IP `192.168.70.2`, Gateway `192.168.70.1` | Fixed route to X28 modem |
| **Active WAN Port** | Auto-detected (currently physical port `lan4`) | Managed by `/usr/sbin/wan-detector` |
| **Physical Port Layout** | Left to Right: Port 1 (`wan`), Port 2 (`lan2`), Port 3 (`lan3`), Port 4 (`lan4`) | Any port can accept the uplink cable |
| **Sing-Box SOCKS Inbound**| `127.0.0.1:1080` | Local socks5 proxy |
| **Sing-Box Redir / Tproxy**| `0.0.0.0:12345` (TCP redir) / `0.0.0.0:12346` (UDP tproxy) | nftables redirect target |
| **Sing-Box DNS Inbound** | `127.0.0.1:5354` (UDP) | Upstream resolver for dnsmasq |
| **Sing-Box Clash API** | `http://127.0.0.1:9090/` (Secret: none) | Proxy selector & latency API |
| **Fail-Open Watchdog** | `/usr/sbin/proxy-watchdog.sh` (`/etc/init.d/proxy-watchdog`) | Probes SOCKS :1080 every 30s; 90s fail-open / 60s restore |
| **Darkstat Monitor** | `http://192.168.1.1:667/` | Real-time per-device traffic graphs (<150KB footprint) |
| **Band Steering Daemon**| Disabled (`/etc/init.d/usteer disable`) | Permanently disabled: incompatible with split SSIDs (`XI-5G` / `XI-2G`); prevents 802.11v kick storms |
| **CAKE SQM QoS** | `lan4` (95M down / 25M up, `diffserv4`, `ack-filter`) | Lowers gaming/voice latency during heavy downloads |
| **Wake-on-LAN Web UI** | LuCI: **Services -> Wake on LAN** | One-click magic packet for `WIN10-PC` and `parsavisions-lan` |

### 2.2. WAN Gateway & Cellular Modem — ZLT X28

| Parameter | Value | Notes |
|---|---|---|
| **Hardware / Model** | Tozed ZLT X28 (MediaTek MT6890 5G, 643 MB RAM) | 4G/5G Cellular Gateway |
| **Operating System** | OpenWrt 19.07-SNAPSHOT (Kernel 4.19.205) | Vendor build, BusyBox 1.30.1 |
| **LAN IP Address** | `192.168.70.1` (Subnet: `255.255.255.0`) | Gateway for AX3000T & ZL clients |
| **DHCP Server Range** | `192.168.70.100` – `192.168.70.200` | Static IP `192.168.70.2` reserved for AX3000T |
| **SSH Access** | `ssh -o HostKeyAlgorithms=+ssh-rsa root@192.168.70.1` | Port 22 (legacy RSA host key required) |
| **SSH Root Password** | `G5K0utrzATYX` | Root credential |
| **Telnet Break-Glass** | `nc 192.168.70.1 23` | Root shell, passwordless, LAN only |
| **Vendor Web UI** | `http://192.168.70.1/` (Port 80 / 443) | Username: `admin`, Password: `admin` |
| **NOC Web Dashboard** | `http://192.168.70.1:8080/` | Custom lightweight dark-mode dashboard |
| **Wi-Fi 5GHz (Backup)** | SSID: **`ZL-5G`** | WPA2-PSK (Independent fallback network) |
| **Wi-Fi 2.4GHz (Backup)**| SSID: **`ZL-2.4G`** | WPA2-PSK |
| **Cellular Connection** | Samantel SIM (MCI 5G NSA, PLMN 43211) | Fallback: Rightel 4G (PLMN 43220) |
| **Baseband Net Interfaces**| `ccmni1` (Default data bearer), `ccmni2` | Cellular network interfaces |
| **Mihomo Proxy Engine** | `/data/proxy/mihomo/mihomo` | SOCKS: `192.168.70.1:1080`, Redir: `:12345` |
| **Mihomo Clash API** | `http://127.0.0.1:9090/` | Local controller on X28 |
| **Telegram Bot** | `@xirouterbot` | Long-polling bot process on X28 |

### 2.3. Remote Proxy Origin — Dual VPS Infrastructure

| Parameter | Value | Notes |
|---|---|---|
| **Server IPv4 (VPS 1 - Primary)** | `85.121.124.158` | Ubuntu 24.04 LTS (Kernel 6.8.0, Hetzner Frankfurt) |
| **Server IPv4 (VPS 2 - Redundant)** | `5.175.234.113` | Ubuntu 24.04 LTS (Kernel 6.8.0, Servitro Frankfurt AMD EPYC 7443P) |
| **SSH Access** | `ssh vps` or `ssh vps2` | Port 22 (Shared key `~/.ssh/id_ed25519_agent`) |
| **s-ui Admin Panels** | VPS1: `http://85.121.124.158:2095/app/`<br>VPS2: `http://5.175.234.113:2095/app/` | Port 2095 (`suiadmin` / VPS1: `Sui-697ebba6619cf922`, VPS2: `Sui-servitro-697e`) |
| **Synchronized Clients** | `parsa`, `tape`, `jafar`, `saeed`, `baba` | Identical UUIDs and Hy2 passwords across both VPS nodes |
| **Subscription URL** | `http://85.121.124.158:2096/sub/` | Subscription endpoint |
| **VLESS+Reality Node** | Port: `443`, UUID: `5ee543a7-9a11-4d0d-b3e6-153945539f60` | SNI: `www.bing.com`, Fingerprint: `chrome` |
| **Reality Public Key** | `fIZg5mhL-DlLT03aBciQw94x6hPOe2_T6ivsRHRyMWA` | Short ID: `7fa7e3ce4165cba3` |
| **Hysteria2 Node** | Port: `31800` (UDP), Password: `p4DyJIAuyp` | Obfs: `salamander`, Pass: `bwne4pabf0tzt00f` |
| **CDN WebSocket Node** | Server: `188.114.98.0:443`, Host/SNI: `cdn.dmbz.ir` | Path: `/v1/status` (Origin port: 8443) |
| **CDN gRPC Node** | Server: `188.114.98.0:443`, Host/SNI: `cdn.dmbz.ir` | serviceName: `vless-grpc` (Origin port: 2053) |
| **Babaii Fallback Node** | Server: `216.45.52.132:23993` | VLESS Vision UUID: `c5716edc-2be0-40d8-cb8a-866f5ce785b6` |
| **Emergency DNS Tunnel (dnstt-server)** | Port: `53` (UDP), Server: `85.121.124.158` (VPS 1) | Daemon: `/usr/local/bin/dnstt-server` (`dnstt.service`) |
| **dnstt Noise Public Key** | `3ac91e6d9222cefc2535c22a83bb9be88353c0bfb63e1698cc13cbb82498946a` | Stored in `/etc/dnstt/server.pub` on VPS and AX3000T |
| **dnstt Tunnel Zone / NS** | Root: `t.dmbz.ir`, Nameserver: `ns.dmbz.ir` (`85.121.124.158`) | Cloudflare DNS-only (`A` + `NS` records) |
| **dnstt Upstream Proxy** | SOCKS5 `127.0.0.1:40000` (Cloudflare WARP `warp-svc`) | Fallback resolver for non-tunnel DNS: `1.1.1.1:53` |

### 2.4. Smart Home & Entertainment — Samsung Q70C QLED TV

| Parameter | Value | Notes |
|---|---|---|
| **Model Code / Series** | `QA55Q70CAUXZN` (`23_NKM2_QTV_T09`) | 2023 Samsung QLED 55" 4K |
| **Operating System** | Tizen OS 9.0 (`armv7` 32-bit) | DUID: `uuid:cd8c3e57-f1f0-492a-a752-d03655f55c09` |
| **LAN IPv4 Address** | `192.168.1.105` | Static DHCP on AX3000T (MAC: `c8:12:0b:32:7c:f2`) |
| **Smart Hub Region** | United States (US) | Sideload-enabled; avoids ATSC region lock via router IPTV |
| **Open Debug Services**| `26101` (SDB), `8001` (REST v2) | Dev Mode Pin `12345` in Apps panel (Host PC: `192.168.1.143`) |
| **Primary Sideloaded Apps**| TizenTube, Jellyfin AVPlay, Moonlight, Stremio, EN-IPTV_Player, Overscan (21 apps) | See [`docs/DEVICE_SAMSUNG_Q70C_TIZEN_ECOSYSTEM.md`](DEVICE_SAMSUNG_Q70C_TIZEN_ECOSYSTEM.md) |
| **Local IPTV Feed** | `http://192.168.1.1/cgi-bin/tv.m3u8` | 588 verified channels; dynamic 32-bit overflow rewriter |

### 2.5. Dedicated HomeLab Server — Legacy PC (Pentium G2030 / H61M-K)

| Parameter | Value | Notes |
|---|---|---|
| **Role & Purpose** | 24/7 Silent HomeLab Server | Docker host, Jellyfin 4K server, qBittorrent, proxy offload |
| **CPU** | Intel Pentium G2030 (3.00 GHz, 2C/2T) | LGA 1155 Ivy Bridge, 55W TDP, Intel HD Graphics iGPU |
| **Motherboard** | ASUS H61M-K (Rev 2.02) | Micro-ATX, Intel H61 Chipset, UEFI BIOS with Q-Fan control |
| **Memory (RAM)** | 10 GB DDR3-1600 (2GB + 8GB) | Dual-channel configuration for multi-container Docker workloads |
| **Discrete GPU** | ZOTAC GT210 (512MB DDR2) | **Removed / Depopulated** for 20W power reduction & headless boot |
| **Storage (HDD)** | 500GB Samsung Spinpoint F3 (7200 RPM) | Model HD502HJ; `hdparm` auto spindown (10 min) for silent operation |
| **Power Supply** | ASUS P.S.I (PS-2000W label) | Actual 12V rail ~168W; quiet acoustic fan profile |
| **CPU Cooler** | NIDEC Intel Stock (E97379-001) | Serviced & lubricated; Green GT-6 paste; BIOS Q-Fan set to `Silent` (~800 RPM) |
| **LAN Connection** | 1 Gbps Ethernet (Realtek RTL8111F) | Direct gigabit cable to Xiaomi AX3000T LAN port |
| **Documentation Reference** | [`docs/DEVICE_LEGACY_HOMELAB_PC.md`](DEVICE_LEGACY_HOMELAB_PC.md) | Complete hardware specifications and acoustic zeroing guide |

### 2.6. Primary Workstation — Lenovo Legion 5 (16IAX10 / Model 83NX)

| Parameter | Value | Notes |
|---|---|---|
| **Commercial Model** | Lenovo Legion 5 16IAX10 | Model Code: `83NX` |
| **Processor (CPU)** | Intel Core Ultra 9 275HX | Arrow Lake-S, 24 Cores (8P + 16E), 24 Threads, up to 5.4 GHz |
| **Memory (RAM)** | 32 GB DDR5-5600 | High-speed dual channel |
| **Primary Storage** | 1 TB Samsung PCIe 4.0 NVMe SSD | Ultra-fast NVMe storage |
| **Discrete GPU (dGPU)** | NVIDIA GeForce RTX 5060 Laptop GPU | 8 GB GDDR6, Blackwell (GB206M), `nvidia-open-dkms 610.57`, RTD3 D3cold |
| **Integrated GPU (iGPU)** | Intel Graphics (Arrow Lake) | `intel-media-driver` (`iHD`), full VA-API hardware decode/encode |
| **Display Panel** | 16" WQXGA (2560x1600, 16:10) | 240Hz, 100% sRGB, Adaptive Sync / VRR |
| **Operating System** | Omarchy Linux (Kernel 7.2.5-3-omarchy) | Hyprland Wayland compositor, dual-boot Windows 11 with WSL2 |
| **Network Interfaces** | Wi-Fi 6E/7 + Realtek 2.5GbE LAN | Static DHCP on `XI-5G`; primary operator terminal |
| **Role in Ecosystem** | Workstation & Moonlight Host | Controls all routers/servers; streams 4K120 HDR games to Samsung Q70C |
| **Documentation Reference** | [`docs/DEVICE_LENOVO_LEGION_5_LAPTOP.md`](DEVICE_LENOVO_LEGION_5_LAPTOP.md) | Workstation configuration, Hyprland VRR, and gaming stack |

### 2.7. Mobile Survival & MITM Edge Appliance — Redmi Note 9S (Curtana)

| Parameter | Value | Notes |
|---|---|---|
| **Commercial Model** | Xiaomi Redmi Note 9S (`curtana` / `miatoll`) | Dedicated survival & field edge node |
| **Processor (SoC)** | Qualcomm Snapdragon 720G (8 Cores, 2.3 GHz) | `arm64-v8a` architecture |
| **Operating System** | Android 16 Custom ROM (Kernel 4.14.348) | Rooted via Magisk 28.x (`uid=0`) |
| **MITM System Root CA** | `CN=Blackout-MITM-Root-CA` (Hash: `2fd38180`) | Injected via `/data/adb/modules/trustusercerts/` |
| **Emergency Storage Bundle**| `/sdcard/Blackout-Prep/` | Offline APKs, checklists, configs, and DNS client |
| **DNS Tunneling Client** | `/sdcard/Blackout-Prep/dnstt-client-arm64` | Launcher: `start_dnstt_phone.sh` (SOCKS5 :5300) |
| **Documentation Reference** | [`docs/DEVICE_REDMI_NOTE_9S_BLACKOUT.md`](DEVICE_REDMI_NOTE_9S_BLACKOUT.md) | Full mobile survival and MITM edge specification |

### 2.8. Third-Party Service Secrets & Tokens

| Service | Key / Identifier | Value | Where Configured |
|---|---|---|---|
| **Telegram Bot Token** | `TOKEN` | `8694642421:AAGtJ85gPna2RTETYVD_-dOmJA9rn4C5qf0` | `/etc/tg.conf` on X28 |
| **Telegram Authorized Chat**| `CHAT_ID` | `2011467832` | `/etc/tg.conf` on X28 |
| **Samantel Portal (AX3000T)**| `SAMANTEL_PHONE` / `PASS` | `09999985823` / `a@nmJ2L@aLyZmRj` | `/etc/samantel.conf` on AX3000T |
| **Samantel Portal (X28)** | `SAMANTEL_PHONE` / `PASS` | `09999985823` / `Rezagolzar4321@#`| `/etc/samantel.conf` on X28 |
| **Router API Auth** | Basic Auth | `xirouter:<token>` | `/etc/routerapp.conf` on AX3000T |

---

## 3. Laptop Hotspot Triage Protocol

### The Problem
When the home network loses internet and you are chatting with an AI agent via phone mobile hotspot (Wi-Fi), connecting an Ethernet cable from your laptop to the AX3000T causes Windows DHCP to assign a default gateway (`192.168.1.1`). Because Windows assigns Ethernet a lower interface metric (`25`) than Wi-Fi (`45`), all internet traffic immediately routes out the broken Ethernet connection, terminating your session.

### The Verified Solution
Run these commands in Windows (elevated PowerShell or Command Prompt) **before or right after** plugging the cable:

```powershell
# 1. Deprioritize Ethernet default route so Wi-Fi hotspot stays primary for internet:
netsh interface ipv4 set interface "Ethernet" metric=9999

# 2. Add static route to X28 modem subnet via AX3000T:
route add 192.168.70.0 mask 255.255.255.0 192.168.1.1 metric 1
```

**Result:**
- Internet & chat continue running uninterrupted through your phone's Wi-Fi hotspot.
- Direct SSH/Ping to AX3000T (`192.168.1.1`) works via the local `192.168.1.0/24` subnet.
- Direct SSH/Ping to X28 (`192.168.70.1`) works routed through `192.168.1.1`.

---

## 4. Component Deep Dive: Xiaomi AX3000T

### 4.1. Network & Interface Layout
- **LAN Bridge (`br-lan`):** Holds physical ports `lan2`, `lan3` (and port `wan` when `lan4` is active WAN). IP: `192.168.1.1/24`.
- **Active WAN (`wan`):** Dynamically bound to the port physically connected to X28 (currently `lan4`). Static IP: `192.168.70.2/24`, Gateway: `192.168.70.1`, DNS: `192.168.70.1`.
- **Guest Bridge (`br-guest`):** Subnet `192.168.3.1/24` with wireless client isolation.

### 4.2. Auto-Sensing WAN Port Daemon (`wan-detector`)
- Binary: `/usr/sbin/wan-detector` under `procd` init `/etc/init.d/wan-detector`.
- Checks carrier states every 10s across `wan`, `lan2`, `lan3`, `lan4`.
- Sends Layer 2 ARP probe for X28's MAC (`98:a9:42:6b:67:b8`).
- Binds matching port to `network.wan.device` and bridges the other 3 ports into `br-lan`.
- Calls `ubus call network reload` cleanly without dropping Wi-Fi.

### 4.3. DNS Chain on AX3000T
```
[Client DNS Query] 
        │ 
        ▼ (:53)
[dnsmasq on AX3000T]
        │
        ├──► Blocklist: /var/run/adblock-fast/dnsmasq.servers (Local NXDOMAIN)
        ├──► Local / Static Leases (/tmp/dhcp.leases, /etc/ethers)
        └──► Upstream Forwarder: 127.0.0.1#5354 (Sing-Box dns-in)
                     │
                     ├──► .ir / geosite-ir ──► dns-direct (192.168.70.1 UDP:53)
                     └──► Foreign / Default ──► dns-proxy (https://8.8.8.8/dns-query via proxy-select)
```
*Note:* If `proxy-select` fails, upstream DoH to `8.8.8.8` will time out, causing `dnsmasq` to report SERVFAIL/timeout to all LAN clients.

### 4.4. Transparent Interception (`axproxy.nft`)
- Table: `inet axproxy` loaded via `/etc/axproxy.sh` on firewall start.
- **TCP Redirection:**
  - Standard web/services: `iifname { "br-lan", "br-guest" } tcp dport { 80, 443, 2053, 2083, 2087, 2096, 4530-4534, 6667, 8080, 8443, 25565, 27015-27050, 28910, 29900, 29901 } redirect to :12345`
  - Valve SDR IP ranges (TCP fallback): `iifname { "br-lan", "br-guest" } meta l4proto tcp ip daddr { 146.66.152.0/21, 146.66.152.0/24, 155.133.128.0/17, 162.254.192.0/18, 185.25.182.0/23, 208.64.200.0/22 } redirect to :12345`
- **UDP TProxy:**
  - Real-time gaming (Steam, Photon, Bedrock Minecraft, GameSpy, STUN/Voice): `iifname { "br-lan", "br-guest" } udp dport { 3478-3480, 4379-4380, 5055-5058, 6500, 8086, 8087, 13139, 19132, 27000-27200, 27900, 27901 } meta mark set 0x1 tproxy ip to :12346 accept`
  - Valve SDR IP ranges (UDP Steam Datagram Relay): `iifname { "br-lan", "br-guest" } meta l4proto udp ip daddr { 146.66.152.0/21, 146.66.152.0/24, 155.133.128.0/17, 162.254.192.0/18, 185.25.182.0/23, 208.64.200.0/22 } meta mark set 0x1 tproxy ip to :12346 accept`
- **QUIC Drop:**
  `udp dport 443 drop` (forces web browsers to fallback to standard TCP HTTP/2 or HTTP/1.1).
- **Private IP Bypass:**
  Traffic destined for `10.0.0.0/8`, `127.0.0.0/8`, `172.16.0.0/12`, `192.168.0.0/16` returns immediately.

### 4.5. Sing-Box Routing Architecture (`/etc/sing-box/config.json`)
- **Outbounds:**
  1. `vps-reality`: VLESS + REALITY over TCP to `85.121.124.158:443` (SNI `www.bing.com`). Primary, fast, resilient.
  2. `via-x28`: SOCKS5 to the X28 Mihomo engine (`192.168.70.1:1080`), inheriting the X28's 46-node rescue pool. Backup path.
  3. `hy2`: Hysteria2 over UDP to `85.121.124.158:31800` (Salamander obfs `bwne4pabf0tzt00f`). Manual-only — MCI currently drops all UDP toward the VPS IP (see §7b).
  4. `cdn-ws`: VLESS + WebSocket over Cloudflare CDN (`cdn.dmbz.ir:443`). Emergency fallback, currently dead upstream.
  5. `direct`: Direct bypass outbound.
  6. `proxy-select`: Manual selector group (`auto`, `vps-reality`, `vps2-reality`, `via-x28`, `hy2`, `cdn-ws`, `vps2-hy2`, `cdn-grpc`).
  7. `auto`: URL-test group, **healthy live nodes only** (`hy2`, `vps-reality`, `vps2-hy2`, `cdn-ws`, `via-x28`), test URL `https://www.gstatic.com/generate_204`, `interval: 30s`, `tolerance: 50`, **`interrupt_exist_connections: true`** (critical: severs hung sockets on node switch instead of stalling browser tabs for minutes). `vps2-reality` is excluded from the auto pool to eliminate recurring 30s dial timeout errors and latency penalties.
  8. `gaming`: Dedicated low-latency URL-test group (`["vps2-hy2", "hy2", "vps-reality"]`) specifically handling real-time gaming, Photon Engine, and Steam/Valve traffic. Test URL `https://www.gstatic.com/generate_204`, `tolerance: 100`, `interval: 30s`, `interrupt_exist_connections: true`. When cellular carrier UDP is healthy, gaming packets ride Hysteria2 (QUIC/BBR) with ~292ms latency and zero head-of-line blocking; if UDP is filtered or throttled, it fails over seamlessly to `vps-reality` TCP.
- **Routing Rules Highlights:**
  - **Steam / Valve SDR Prefixes:** `155.133.128.0/17`, `162.254.192.0/18`, `146.66.152.0/21`, `208.64.200.0/22`, `185.25.182.0/23`, `146.66.152.0/24` route to `gaming`.
  - **Photon Engine & Games:** `photonengine.io`, `photonengine.cn`, `exitgames.com` and ports `27000:27200`, `5055:5058`, `3478:3480`, `4379:4380`, `27015:27050`, `4530:4534` route to `gaming`.
  - **Domestic Bypass:** `geosite-ir`, `geoip-ir`, `.ir` TLDs route to `direct`.
  - **Default / Foreign:** Uncategorized traffic routes to `proxy-select`.
- **Canonical template:** `router/sing-box-config.json` in the repo. Dead nodes must never be listed inside `auto` — they stall every urltest cycle and freeze DNS (domino pattern of the Sept 14 outage).
- **Clash Controller API:**
  Listening on `127.0.0.1:9090` without auth.
  - Query active node: `curl -s http://127.0.0.1:9090/proxies/proxy-select`
  - Switch active node: `curl -s -X PUT -d '{"name":"auto"}' http://127.0.0.1:9090/proxies/proxy-select`

### 4.6. Autonomous Fail-Open Watchdog Daemon (`proxy-watchdog`)
- Script: `/usr/sbin/proxy-watchdog.sh` under `procd` init `/etc/init.d/proxy-watchdog`.
- Probes `127.0.0.1:1080` (SOCKS) every 30s using **Dual-Endpoints** (Google 204 + Cloudflare 204). A failure is only recorded if BOTH endpoints fail.
- **Fail-Open Transition (5 consecutive dual-failures = 150s / 2.5 min):**
  1. Flushes `table inet axproxy` in nftables (all client TCP traffic immediately bypasses proxy and routes directly over cellular).
  2. Points `dhcp.@dnsmasq[0].server` directly to `192.168.70.1` and restarts dnsmasq (clean, instant domestic DNS).
- **Recovery Transition (3 consecutive passes = 90s stability):**
  1. Re-applies `/etc/axproxy.sh` (transparent interception restored).
  2. Reverts `dnsmasq` server to `127.0.0.1#5354` (encrypted DoH restored).
- Anti-flap tuned: Sing-Box `urltest` tolerance `75ms`, check interval `30s`, and `interrupt_exist_connections: true` (hung sockets are severed on node switch instead of stalling clients).
- Zero reboots, zero packet loss, state tracked in `/tmp/proxy-watchdog.state`.

### 4.7. Autonomous IPTV Streaming Proxy & Sanitizer (Samsung TV Support)
To resolve the ATSC broadcast lock on US-region Samsung TVs and bypass Samsung Tizen's 32-bit signed integer buffer overflow bug (`EXT-X-MEDIA-SEQUENCE > 2,147,483,647` on Telewebion HLS streams), the AX3000T hosts a specialized on-demand manifest proxy:
- **Master M3U Endpoint:** `http://192.168.1.1/cgi-bin/tv.m3u8` (symlinked from `/www/cgi-bin/playlist`) serving 588 categorized, deep-verified live streams with standard `application/vnd.apple.mpegurl` headers and CORS.
- **Rendition Router (`/www/cgi-bin/stream`):** Dynamically exposes 480p, 720p, and 1080p stream URLs per channel.
- **Dynamic Media Sanitizer (`/www/cgi-bin/media`):**
  1. Resolves Telewebion's live edge node on-demand (zero stale links).
  2. Truncates upstream 16-digit sequence numbers to 9 digits (`mod 1,000,000,000`), completely eliminating the 2-second buffer freeze on Samsung AVPlay / Tizen MSE.
  3. Rewrites chunk paths to absolute CDN URLs so MPEG-TS video data streams directly from Iranian CDNs to the TV with 0% router bandwidth consumption.
- **Sing-Box Domestic Direct Interception:** `telewebion.com`, `telewebion.net`, `telewebion.ir`, `sepehrtv.ir`, `anten.ir`, `lenz.ir`, and `irib.ir` route strictly to `direct` and resolve via `dns-direct` (`192.168.70.1`), preserving Iranian domestic peering rates and zero-block delivery.
- **Detailed Reference:** See [`docs/DEVICE_SAMSUNG_Q70C_TIZEN_ECOSYSTEM.md`](DEVICE_SAMSUNG_Q70C_TIZEN_ECOSYSTEM.md).

### 4.8. Cold-Boot RTC Clock Skew Mitigation (`clock-guard`)
The MediaTek MT7981B board lacks an RTC backup battery. On cold-boot or power-cycle events, OpenWrt restores a stale filesystem timestamp (`sysfixtime`) which may lag real time by hours or days. Because the VLESS+Reality protocol strictly validates client timestamps against the remote server (tolerance ~120s), handshake attempts fail with `inbound/vless: TLS handshake: REALITY: processed invalid connection`.
- **Root-Cause Domino:** Stale clock → REALITY handshakes rejected → Proxy-watchdog detects 5 consecutive probe timeouts → Watchdog triggers fail-open → dnsmasq queries cellular ISP DNS → MCI poisoning caches `0.1.0.1` locally → Outage persists even after tunnel recovery.
- **Autonomous Recovery Guard:** `/etc/rc.local` runs a background one-shot NTP synchronization loop:
  ```sh
  (
      for i in 1 2 3 4 5 6 7 8 9 10 11 12; do
          ntpd -q -p 0.openwrt.pool.ntp.org -p 1.openwrt.pool.ntp.org >/dev/null 2>&1 && break
          sleep 10
      done
      logger -t clock-guard "NTP one-shot done, clock=$(date -u +%FT%TZ)"
  ) &
  ```
- **Direct NTP Path:** NTP operates via direct UDP port 123 over cellular without detouring through the proxy, ensuring accurate time synchronization prior to establishing REALITY connections.

### 4.9. MediaTek WED Hardware Acceleration & 5G Cellular MTU Clamping
- **WED (Wireless Ethernet Dispatch v1):**
  - Filogic 820 (MT7981B) silicon DMA ring offloading between the `mt7915` Wi-Fi 6 radio and on-chip Ethernet switch.
  - Enabled via `/etc/modules.d/mt7915e`: `options mt7915e wed_enable=Y`.
  - Accelerates L2 packet transfer without bypassing L3 netfilter hooks or `tc` CAKE qdiscs. Cuts Wi-Fi CPU interrupt overhead by 40–50%, maintaining ample CPU headroom for Sing-Box TLS encryption.
- **Cellular PMTUD Clamping (MTU 1420):**
  - Set via `uci set network.wan.mtu='1420' && uci commit network`.
  - Eliminates the PMTUD black hole caused by carrier GTP-U tunnel encapsulation overhead (36–64 bytes) over MCI/Samantel 5G NSA. Prevents packet drops when upstream servers return responses with the DF (Don't Fragment) bit set.

### 4.10. Sing-Box Outbound TLS Record Fragmentation
To evade carrier-grade DPI (Huawei SIG / Sandvine / domestic UPF inspection) targeting VLESS Reality and Cloudflare CDN handshakes:
- **Parameter:** `"record_fragment": true` enabled under all TLS outbounds (`vps-reality`, `vps2-reality`, `cdn-ws`, `cdn-grpc`) in `/etc/sing-box/config.json`.
- **Mechanism:** Splits the TLS `ClientHello` across multiple TLS record headers inside the same TCP connection. Bypasses wire-speed SNI extraction without introducing latency or requiring external tunnel wrappers.

### 4.11. Static Verified Binary Rule-Sets (.srs)
- **Format:** High-performance binary rule-sets compiled with `.srs` extension (RAM footprint ~300KB vs tens of MBs in legacy `.dat` format).
- **Rule-sets Deployed (9 files in `/etc/sing-box/`):** `geoip-ir.srs`, `geosite-ir.srs`, `geosite-category-bank-ir.srs`, `geosite-youtube.srs`, `geosite-google.srs`, `geosite-instagram.srs`, `geosite-facebook.srs`, `geoip-arvancloud.srs`, `geoip-derakcloud.srs`.
- **Static & Frozen Policy:** No background cron jobs or automated external fetching. Rules are verified, local, and immutable to prevent upstream corruption or internet outages while unattended.

### 4.12. Samsung Q70C TV Supervision Helper
- **Script:** `/usr/sbin/tv-control.sh`.
- **Target:** Samsung Q70C 55" QLED (`192.168.1.105`, MAC `c8:12:0b:32:7c:f2`).
- **Commands:**
  - `/usr/sbin/tv-control.sh wake`: Transmits Wake-on-LAN magic packet over `br-lan`.
  - `/usr/sbin/tv-control.sh status`: Queries TV REST API `:8001/api/v2/` to check power state.

### 4.13. Kernel Network Buffer & High-Throughput Proxy Tuning
- **Location:** `/etc/sysctl.conf` on AX3000T.
- **Problem Solved:** OpenWrt default socket memory caps (`rmem_max` and `wmem_max` at 208 KB) constrained TCP/UDP window scaling and caused buffering bottlenecks during concurrent encrypted proxy transfers and HLS video streaming.
- **Parameters Applied:**
  ```ini
  # Network socket buffer tuning for high-throughput proxying
  net.core.rmem_max=4194304
  net.core.wmem_max=4194304
  net.ipv4.tcp_rmem=4096 87380 4194304
  net.ipv4.tcp_wmem=4096 65536 4194304
  ```
- **Operational Impact:** Increases socket buffer ceilings to 4 MB per stream, allowing TCP BBR and Hysteria2 QUIC congestion windows to scale to the full 5G cellular link capacity with minimal packet drop retransmissions.

### 4.14. Deep Architecture Modules & Engine Redesign (September 2026)

Following a comprehensive architectural audit and the principles of deep module design, the core router automation, telemetry, and presentation systems were refactored from shallow shell scripts into four deep, highly cohesive modules with simple, unified boundaries:

#### 1. Consolidated Device Registry (`/root/device-registry.sh`)
- **Problem Solved:** Fragmented MAC-to-hostname resolution logic across the Telegram bot, Router API, dashboard, and CLI tools, which previously caused repeated regex parsing loops, hostname cache desynchronization, and subshell performance penalties.
- **Architecture & Precedence:** Provides a single, authoritative resolution hierarchy:
  1. *User Override:* `/etc/usage-log/user-names` (explicit friendly names assigned by admin).
  2. *Active DHCP Lease:* `/tmp/dhcp.leases` (live hostnames announced by devices).
  3. *Hostname Cache:* `/etc/usage-log/names` (persisted historical device names).
  4. *Deterministic Fallback:* `Unknown-XX:XX:XX` (derived from the MAC address).
- **Design Leverage:** Employs dynamic path getters (`dev_reg_un_path()`, `dev_reg_dl_path()`, `dev_reg_nc_path()`, `dev_reg_wl_path()`) so unit test suites and CLI tools can isolate environments without re-sourcing.
- **Exposed API:**
  - `dev_reg_name <mac>`: Returns canonical display name.
  - `dev_reg_get <mac>`: Emits pipe-delimited metadata record (`mac|name|source|is_watched`).
  - `dev_reg_rename <mac> <new_name>`: Atomically mutates user-names override file.
  - `dev_reg_set_watch <mac> <0|1>`: Manages high-priority device surveillance list.
  - `dev_reg_is_watched <mac>`: Returns boolean exit code (0 if watched, 1 otherwise).
- **Test Coverage:** Verified by `router/tests/test_device_registry.sh` (9/9 pass).

#### 2. Unified Proxy Supervisor & State Machine (`/root/proxy-supervisor.sh`)
- **Problem Solved:** Port drift between stale configuration references (`:1070`) and canonical SOCKS inbound (`127.0.0.1:1080`), combined with split health-checking logic between watchdog daemons and diagnostic scripts.
- **Architecture & Health State Machine:**
  - *Dual-Endpoint Probing:* Concurrently tests Google HTTP 204 (`generate_204`) and Cloudflare HTTP 204. A failure is only recorded if BOTH endpoints fail or timeout, preventing false-positive failovers.
  - *Hysteresis State Machine:* Tracks failure counts and recovery passes in state file `/tmp/proxy-watchdog.state` (`STATE|FAIL_COUNT|PASS_COUNT`).
  - *Fail-Open Transition (5 consecutive failures = 150s):* Flushes `table inet axproxy` in nftables and redirects dnsmasq upstream to `192.168.70.1`.
  - *Recovery Transition (3 consecutive passes = 90s):* Re-applies `/etc/axproxy.sh` and points dnsmasq upstream to `127.0.0.1#5354`.
- **Exposed API:**
  - `proxy_sup_probe [socks_host] [socks_port] [timeout_s]`: Probes dual endpoints through SOCKS.
  - `proxy_sup_status`: Queries current operational state and consecutive counts.
  - `proxy_sup_switch <mode>`: Manually forces `failopen` or `recovery` transitions.
  - `proxy_sup_tick`: Autonomous evaluation tick executed every 30 seconds by `/usr/sbin/proxy-watchdog.sh`.
- **Test Coverage:** Verified by `router/tests/test_proxy_supervisor.sh` (16/16 pass).

#### 3. Unified Billing & Serialization Engine (`/root/billing.sh`)
- **Problem Solved:** Duplicated arithmetic and string interpolation across `usage.sh`, `routerapi_lib.sh`, and bot scripts for calculating Iranian Toman costs, Friday discount rates, and volume roundings.
- **Architecture & Pricing Engine:**
  - *Rate Resolution:* Canonical rates resolved from `/etc/usage-log/billing.conf` (`RATE_FULL=7700` Toman/GB, `RATE_FRIDAY=4620` Toman/GB).
  - *Configurable Rounding Boundary:* Configured by `ROUND_TOMAN` (defaults to 1,000 Toman for clean consumer-friendly figures).
  - *Stream-Based Serialization:* Reads usage records directly from `/root/usage.sh` and transforms them into:
    1. *Monospace Text Table:* Human-readable aligned tables with percentage shares for Telegram (`--today`, `--month`).
    2. *Strict JSON:* RFC 8259-compliant JSON streams with machine-readable totals for the Router API (`--json-today`, `--json-month`).
- **Exposed API:**
  - `billing_rates`: Emits `RATE_FULL|RATE_FRIDAY|ROUND_TOMAN`.
  - `billing_rate_for <is_friday>`: Returns active rate per GB in Toman.
  - `billing_calc_toman <bytes> <is_friday>`: Pure integer arithmetic returning rounded Toman.
  - `billing_stream_to_text <is_friday> <period_label>`: Formats tabular monospace text.
  - `billing_stream_to_json <is_friday>`: Emits structured JSON payload.
  - `billing_render <json|text> <today|month> [is_friday] [YYYY-MM]`: Unified facade for consumers.
- **Test Coverage:** Verified by `router/tests/test_billing_engine.sh`, `test_cost.sh`, and `test_bill.sh`.

#### 4. Telegram HTML Card Presenter (`/root/tg-presenter.sh` & `/data/proxy/tg-presenter.sh`)
- **Problem Solved:** Code duplication between AX3000T (`botcmd.sh`) and X28 (`x28-bot.sh`) for rendering Telegram cards, resulting in broken local file paths when the X28 bot attempted to call AX3000T scripts directly.
- **Architecture & Presentation Engine:**
  - *Pure Presentation Boundary:* Zero state, zero network I/O, zero router-specific binaries. Pure POSIX text and HTML generation.
  - *Cross-Device Deployment:* Identical copies deployed to `/root/tg-presenter.sh` on AX3000T and `/data/proxy/tg-presenter.sh` on X28.
- **Exposed Capabilities:**
  - `tg_pres_esc <text>`: HTML entity escaping (`&`, `<`, `>`).
  - `tg_pres_card <title> <content>`: Standard HTML monospace card (`<b>title</b><pre>content</pre>`).
  - `tg_pres_blockquote <title> <content>`: Expandable HTML quote (`<blockquote expandable>`).
  - `tg_pres_bar <pct> [width]`: Unicode visual progress gauge (`▰▰▰▰▰▱▱▱▱▱`).
  - `tg_pres_spark <pipe_separated_values>`: 8-level monotonic trend sparkline (` ▂▃▄▅▆▇█`).
  - `tg_pres_temp_badge <temp_c>`: Color-coded temperature badge (`🟢` <60°C, `🟠` <75°C, `🔴` >=75°C).
  - `tg_pres_verdict <health_line>`: Emojified health status badge (`✅`, `⚠️`, `❌`).
- **Test Coverage:** Verified by `router/tests/test_tg_presenter.sh` (14/14 pass).

### 4.14. X28 Cellular & Resilience Deep Modules (Round 2 Architecture)
- **Modem Supervisor (`router/x28/modem-supervisor.sh`):**
  - Unified AT command dispatch (commands 401 & 270) with RFC 8259 JSON and key=val telemetry.
  - Hysteresis PLMN state machine with 600s cooldown and storm-guard limit (max 3/hr).
  - Deployed to `/data/proxy/modem-supervisor.sh` and `/root/modem-supervisor.sh`.
  - Test Suite: `router/tests/test_modem_supervisor.sh` (6/6 pass).
- **Rescue Pool Batch Streaming Engine (`router/x28/rescue-convert.sh`, `router/x28/x28-rescue.sh`):**
  - Replaced 300+ subshell process forks in VMess base64 conversion with single JQ streaming pipeline.
  - Eliminated N+1 member polling in Mihomo health checks with single bulk `/proxies` API query.
  - Test Suites: `test_rescue_convert.sh` (45/45 pass), `test_rescue_engine.sh` (3/3 pass), `test_rescue_supervisor.sh` (12/12 pass).
- **Separated WAN Outage SLA & Household Billing Ledgers:**
  - `router/x28/outage-ledger.sh`: WAN MTTR, downtime tracking, and monthly Jalali SLA reports.
  - `router/x28/billing-ledger.sh`: Household bandwidth billing, Friday discount math, and owner quota attribution.
  - Test Suites: `test_outage_ledger.sh` (21/21 pass), `test_ledger_store.sh` (24/24 pass), `test_people.sh` (23/23 pass).
- **Idempotent DNS Manager (`router/x28/x28-dns.sh`):**
  - Decoupled L7 DNS from L3/L4 iptables routing.
  - Atomic config swapping: validates md5 checksum before touching dnsmasq daemon; purges rogue DHCP DNS `114.114.114.114`.
  - Replaces redundant `dns-fallback.sh`.
  - Test Suite: `test_x28_dns.sh` (4/4 pass), `test_dns_fix.sh` (4/4 pass).

---

## 5. Component Deep Dive: ZLT X28 Modem & Edge

### 5.1. Cellular Stack & Link State
- **SoC:** MediaTek MT6890 5G CPE baseband.
- **Interfaces:** `ccmni1` (primary cellular data bearer), `br0` (LAN bridge `192.168.70.1`).
- **SIM:** Samantel (roaming on MCI 5G NSA `43211`).
- **DNS Cleanliness:** In tunnel mode, `dns-fix.sh` points `/etc/dnsmasq.conf` to `127.0.0.1#5353` (Mihomo DoH) to prevent Iranian ISP NXDOMAIN/poisoning on censored domains.

### 5.2. Mihomo Backup Engine (`/data/proxy/mihomo/`)
- Config: `/data/proxy/mihomo/config.yaml`.
- Mixed Port: `192.168.70.1:1080` (SOCKS5 / HTTP).
- Redirect Port: `12345`.
- External Controller: `127.0.0.1:9090`.
- Outbound Groups:
  - `auto`: url-test between `vps-reality`, `cdn-ws`, `hy2`, and `babaii`.
  - `rescue`: url-test on public scraped nodes (`/data/proxy/mihomo/rescue-pool.yaml`).
  - `world`: selector group between `auto` and `rescue`.
- **AX3000T Bypass:**
  In `tproxy-enable.sh` / `tproxy-fixed-enable.sh`, packets from `192.168.70.2` hit a `RETURN` rule in iptables, preventing double-proxying of AX3000T traffic.

### 5.3. Background Daemon Inventory on X28
All resident processes on the X28 live under `/data/proxy/` or `/root/`:

| Process / Script | Invocation | Responsibility |
|---|---|---|
| `x28-bot.sh supervise` | Loop | Telegram bot runner (`@xirouterbot`) using SOCKS `192.168.70.1:1080` |
| `operator-watchdog.sh` | Loop | Monitors cellular registration; enforces stickiness to MCI (PLMN 43211) |
| `balance.sh` | Cron / Loop | Polls Samantel PWA API, calculates remaining GiB, triggers depletion alerts |
| `x28-dash-data.sh` | Loop | Renders HTML/JSON for the NOC Web Dashboard at `http://192.168.70.1:8080/` |
| `x28-telemetry.sh` | Every 3600s | Appends hourly usage, balance, and proxy latency records |
| `x28-vps-heal.sh` | Loop | Probes VPS health; triggers automated panel/service rescue if dead |
| `x28-drift.sh` | Loop | Verifies checksum of critical configs to detect unauthorized drift |
| `x28-maint.sh` | Loop | Performs weekly Sunday maintenance & garbage collection |
| `x28-rescue.sh` | Loop | Scrapes and admits candidate backup proxy nodes into `rescue-pool` |
| `x28-thermal-loop.sh` | Loop | Monitors MediaTek SoC temperature and mitigates thermal throttling |

---

## 6. Remote VPS Infrastructure

### 6.1. Dual-VPS Topology & Packet Flow Diagram

```
                                  [ LAN & Wi-Fi Clients ]
                         (Phones, Laptops, Samsung Q70C QLED TV)
                                             │
                                             ▼
                      ┌──────────────────────────────────────────────┐
                      │    Xiaomi AX3000T Router (192.168.1.1)       │
                      │  · SmartDNS (:6053): Lowest-RTT Iran CDNs   │
                      │  · 5G Adaptive SQM: Dynamic CAKE 35-110Mbps  │
                      │  · sing-box Core: urltest auto-failover      │
                      └──────────────┬───────────────────────────────┘
                                     │
                 ┌───────────────────┴───────────────────┐
                 │                                       │
                 ▼                                       ▼
     [ International Gateway ]               [ Cloudflare Edge ]
          MCI 5G / Rightel                    (188.114.99.0:443)
                 │                                       │
        ┌────────┴────────┐                              │ (Reverse Proxy)
        │                 │                              │
        ▼                 ▼                              ▼
┌──────────────────┐ ┌──────────────────┐ ┌──────────────────────────────┐
│   VPS 1 (Primary)│ │  VPS 2 (Backup)  │ │      Cloudflare Origin       │
│  85.121.124.158  │ │  5.175.234.113   │ │        cdn.dmbz.ir           │
├──────────────────┤ ├──────────────────┤ ├──────────────────────────────┤
│ Hetzner FSN1     │ │ Servitro FNK1    │ │ VLESS gRPC  (:2053)          │
│ AMD / Ubuntu24   │ │ EPYC 7443P / 24  │ │ VLESS WS    (:8443)          │
├──────────────────┤ ├──────────────────┤ └──────────────┬───────────────┘
│ Kernel: BBR + FQ │ │ Kernel: BBR + FQ │                │
│ PREROUTING NAT:  │ │ PREROUTING NAT:  │                │
│ 20K-50K UDP ────►│ │ 20K-50K UDP ────►│                │
│     :31800       │ │     :31800       │                │
├──────────────────┤ ├──────────────────┤                │
│ s-ui Core Engine │ │ s-ui Core Engine │                │
│ · Reality (:443) │ │ · Reality (:443) │◄───────────────┘
│ · Hy2    (:31800)│ │ · Hy2    (:31800)│ (Multiplexed Tunneling)
│ · SQLite: parsa, │ │ · SQLite: parsa, │
│   tape, jafar,   │ │   tape, jafar,   │
│   saeed, baba    │ │   saeed, baba    │
└──────────────────┘ └──────────────────┘
```

### 6.2. Service Architecture & Node Inventory
- **Primary Node (VPS 1 - `85.121.124.158`):**
  - OS: Ubuntu 24.04 LTS (Kernel 6.8.0), BBR + FQ enabled.
  - Location / Provider: Frankfurt (Hetzner FSN1-DC14).
  - S-UI (`/usr/local/s-ui/sui`) running as systemd `s-ui.service` (alias `sui`).
  - Web Panel: `http://85.121.124.158:2095/app/` (`suiadmin` / `Sui-697ebba6619cf922`)
  - `443/tcp`: `REALITY-443` (VLESS + REALITY, SNI: `www.bing.com`, pbk: `fIZg5mhL-DlLT03aBciQw94x6hPOe2_T6ivsRHRyMWA`, sid: `7fa7e3ce4165cba3`)
  - `31800/udp` + **Port Hopping (`20000:50000/udp` -> `31800` via iptables PREROUTING)**: `HYSTERIA2-31800` (Hysteria2, salamander obfs: `bwne4pabf0tzt00f`, auth pass: `p4DyJIAuyp`)
  - `8443/tcp`: `CDN-WS-8443` (VLESS + WebSocket, reverse-proxied behind `cdn.dmbz.ir:443`, path: `/v1/status`)
  - `2053/tcp`: `CDN-GRPC-2053` (VLESS + gRPC, serviceName: `vless-grpc`, reverse-proxied behind `cdn.dmbz.ir:443`)

- **Redundant Node (VPS 2 - `5.175.234.113` - Servitro Frankfurt AMD EPYC 7443P):**
  - OS: Ubuntu 24.04 LTS Minimal (Kernel 6.8.0), BBR + FQ + 16MB buffers enabled in `/etc/sysctl.d/99-proxy.conf`.
  - Location / Provider: Frankfurt (Servitro Datacenter).
  - SSH Access: `ssh vps2` (uses `~/.ssh/id_ed25519_agent`).
  - S-UI (`/usr/local/s-ui/sui` v1.6.3) running as systemd `s-ui.service`.
  - Web Panel: `http://5.175.234.113:2095/app/` (`suiadmin` / `Sui-servitro-697e`)
  - `443/tcp`: `REALITY-443` (VLESS + REALITY, identical pbk/sid/SNI to VPS 1 for seamless client fallback)
  - `31800/udp` + **Port Hopping (`20000:50000/udp` -> `31800` via iptables PREROUTING)**: `HYSTERIA2-31800` (Hysteria2, identical Salamander obfs & TLS cert hash to VPS 1)
  - All users synchronized: `parsa`, `tape`, `jafar`, `saeed`, `baba` with shared UUIDs and passwords.

### 6.3. AX3000T Router Auto-Failover Integration (`/etc/sing-box/config.json`)
The home router balances and auto-switches between both VPS nodes:
- **`auto` group (`urltest`):** Probes `vps-reality`, `vps2-reality`, and fallback `via-x28` every 30s. If VPS 1 drops or suffers packet loss, traffic fails over to VPS 2 instantly.
- **`gaming` group (`urltest`):** Probes `vps2-hy2`, `hy2`, and `vps-reality`. Routes gaming UDP ports (`27000:27200`, `5055:5058`, etc.) over the lowest-latency Hysteria2 link.
- **`proxy-select` group (`selector`):** Contains `auto`, `vps-reality`, `vps2-reality`, `via-x28`, `hy2`, `cdn-ws`, `vps2-hy2`, and `cdn-grpc`.
- **Clean IP Tuning:** `cdn-ws` and `cdn-grpc` benchmarked via `cfray` and bound to low-jitter edge `188.114.99.0`.

### 6.4. SmartDNS Engine (`/etc/config/smartdns`, port 6053)
- **Architecture & Footprint:** High-performance pure C DNS daemon on OpenWrt 25.12.5 with `<9MB` memory consumption.
- **Speed-Racing Mechanism:** Queries upstream resolvers in parallel, actively pings returned IPs via ICMP & TCP ports 80/443, and returns only the lowest-latency IP to clients.
- **Upstream Resolvers Configured:**
  - `192.168.70.1:53` (ZLT X28 Cellular Gateway)
  - `178.22.122.100:53` & `185.51.200.2:53` (Shecan Anti-Sanction)
  - `85.15.1.14:53` (Shatel DNS)
  - `78.157.42.100:53` (Electro)
- **Sing-Box Bridge:** Sing-box's `"dns-direct"` target in `/etc/sing-box/config.json` points to `"127.0.0.1:6053"`, ensuring all domestic domains, Samsung Q70C IPTV feeds, and Iranian payment gateways resolve to the optimal CDN edge.

### 6.5. 5G Adaptive CAKE SQM Daemon (`/usr/sbin/5g-adaptive-sqm.sh`)
- **Problem Solved:** Overcomes static SQM bottlenecks on cellular connections where signal fluctuations cause bandwidth to oscillate between 20 Mbps and 120 Mbps.
- **Service Management:** Supervised by OpenWrt procd via `/etc/init.d/adaptive-sqm` (`respawn 3600 5 0`).
- **Dynamic Shaping Logic:**
  - Probes gateway RTT every 5 seconds.
  - Target RTT $\le 35\text{ms}$: Clean link $\to$ increments download by 5 Mbps (up to 110 Mbps ceiling) and upload by 1.5 Mbps (up to 30 Mbps ceiling).
  - Target RTT $> 60\text{ms}$: Congestion / tower bufferbloat $\to$ drops download by 15 Mbps (floor 35 Mbps) and upload by 4 Mbps (floor 12 Mbps) dynamically modifying `tc qdisc` on `lan4` and `ifb4lan4`.

### 6.6. UDP Port Hopping Firewall Architecture (VPS 1 & VPS 2)
- **Problem Solved:** Prevents MCI/TIC DPI rate-limiting and temporary port-blocking on Hysteria 2 port `31800` during sustained high-throughput downloads.
- **Implementation:** Kernel PREROUTING redirect rule:
  ```bash
  iptables -t nat -A PREROUTING -p udp --dport 20000:50000 -j REDIRECT --to-ports 31800
  ```
- **Persistence:** Managed by `iptables-persistent` (`netfilter-persistent.service`) on Ubuntu 24.04 across reboots. Clients can connect to any UDP port between `20000` and `50000`.

### 6.7. Granular Iranian Bypass & Banking Rules (Chocolate4U Binary `.srs`)
- Located in `/etc/sing-box/`:
  - `geosite-category-bank-ir.srs`: Complete Iranian banks, Shaparak, payment gateways, and fintechs.
  - `geoip-arvancloud.srs` & `geoip-derakcloud.srs`: Domestic CDN server ranges.
- DNS routing: `geosite-category-bank-ir` queries routed directly to SmartDNS (`dns-direct` on `127.0.0.1:6053`).
- IP routing: Bank domains and domestic CDNs routed directly via `direct` outbound, eliminating anti-fraud IP lockouts and payment failures.

### 6.8. Emergency DNS Tunneling Tier (`dnstt` Blackout Survivability)
- **Problem Solved:** National Internet Blackout ("روز قطعی" / National Information Network isolation):
  - In a full blackout, all outbound non-port-53 UDP (QUIC, WireGuard, Hysteria 2, TUIC) is dropped.
  - Foreign IP routing for TCP connections to major VPS providers (Hetzner, Servitro, DigitalOcean) is severed or subjected to RST injection.
  - TLS ClientHello packet fragmentation is rendered ineffective due to stateful DPI TCP reassembly.
  - The only surviving outbound path is UDP port 53 (DNS) queries forwarded through domestic recursive resolvers (`10.10.34.35`, MCI, Irancell, TCI, `8.8.8.8`, `4.2.2.4`).
- **Server Deployment (VPS 1 — `85.121.124.158`):**
  - Binary: `/usr/local/bin/dnstt-server` (compiled from source).
  - Systemd Service: `/etc/systemd/system/dnstt.service`:
    ```ini
    [Unit]
    Description=DNSTT DNS Tunnel Server
    After=network.target warp-svc.service

    [Service]
    Type=simple
    User=root
    ExecStart=/usr/local/bin/dnstt-server -udp :53 -privkey-file /etc/dnstt/server.key -fallback 1.1.1.1:53 t.dmbz.ir 127.0.0.1:40000
    Restart=always
    RestartSec=3
    LimitNOFILE=65536

    [Install]
    WantedBy=multi-user.target
    ```
  - Port & Fallback: Binds UDP `:53`. Non-tunnel DNS probes fall back to Cloudflare resolver `1.1.1.1:53`.
  - Upstream Egress: Forwards decapsulated KCP/Noise streams to Cloudflare WARP local SOCKS5 proxy on `127.0.0.1:40000`, guaranteeing clean unmonitored egress to the global internet.
  - Server Cryptographic Identity: Noise public key `3ac91e6d9222cefc2535c22a83bb9be88353c0bfb63e1698cc13cbb82498946a` (saved in `/etc/dnstt/server.pub`).
- **Authoritative DNS Zone Delegation (Cloudflare):**
  - `A` Record: `ns.dmbz.ir` $\to$ `85.121.124.158` (Proxy Status: **DNS only / Grey Cloud**, TTL: Auto).
  - `NS` Record: `t.dmbz.ir` $\to$ `ns.dmbz.ir` (Proxy Status: **DNS only / Grey Cloud**).
  - Mechanism: Recursive resolvers querying `*.t.dmbz.ir` discover `ns.dmbz.ir` as the authoritative nameserver and relay Base32-encoded payloads directly to `85.121.124.158:53`. The client inside Iran never initiates a direct IP packet to the VPS, bypassing IP-based blacklisting.
- **AX3000T Router Client Integration:**
  - Client Binary: `/usr/local/bin/dnstt-client` (`aarch64`, Go 1.24 stripped, 8.1MB).
  - Standby Service: `/etc/init.d/dnstt` (OpenWrt procd, inactive by default).
  - Local Listener: SOCKS5 interface on `127.0.0.1:5300`.
  - Sing-Box Outbound Integration (`/etc/sing-box/config.json`):
    ```json
    {
      "type": "socks",
      "tag": "dnstt-emergency",
      "server": "127.0.0.1",
      "server_port": 5300
    }
    ```
    Included in the `proxy-select` selector group. Excluded from `auto` urltest group to prevent constant DNS query overhead and recursive resolver rate-limiting.
  - Start Command on Router: `/etc/init.d/dnstt start`
- **Workstation / Laptop Client Tier:**
  - Startup Script: `~/blackout_binaries/start_dnstt_laptop.sh`
  - Runs `dnstt-client-amd64` connecting via recursive resolver (default `8.8.8.8:53`), providing SOCKS5 on `127.0.0.1:5300`.
- **Mobile Rooted Device Tier (Redmi Note 9S Curtana):**
  - Android 16 custom ROM with Magisk root.
  - Magisk `trustusercerts` module installed at `/data/adb/modules/trustusercerts/system/etc/security/cacerts/2fd38180.0` (10-year root CA) enabling MITM Domain Fronting without user certificate warnings.
  - Offline Emergency Survival Bundle located at `/sdcard/Blackout-Prep/` containing `dnstt-client-arm64`, `start_dnstt_phone.sh`, offline APKs (PattNG, Psiphon, Briar, NekoBox, Kiwix, OrganicMaps), and curated configs.

### 6.9. S-UI Management Commands
```bash
# VPS 1:
ssh vps "systemctl restart sui"
ssh vps "ss -tulpn | grep -E ':443|:31800|:2053|:8443|:2095'"

# VPS 2:
ssh vps2 "systemctl restart s-ui"
ssh vps2 "ss -tulpn | grep -E ':443|:31800|:2095'"

# Tail live connection logs:
ssh vps "journalctl -u sui -f -n 50"
ssh vps2 "journalctl -u s-ui -f -n 50"
```

### 6.9. VPS TCP & Buffer Tuning
- VPS 1: `/etc/sysctl.d/99-bbr-buffer-tune.conf`
- VPS 2: `/etc/sysctl.d/99-proxy.conf`
  - `net.core.default_qdisc = fq`
  - `net.ipv4.tcp_congestion_control = bbr`
  - `net.ipv4.tcp_fastopen = 3`
  - `net.ipv4.tcp_rmem = 4096 87380 16777216`
  - `net.ipv4.tcp_wmem = 4096 65536 16777216`
  - `net.core.rmem_max = 16777216`
  - `net.core.wmem_max = 16777216`
  - `net.ipv4.ip_forward = 1`
  - `net.ipv4.tcp_congestion_control = bbr`
  - `net.ipv4.tcp_fastopen = 3`
  - `net.ipv4.tcp_rmem = 4096 87380 16777216`
  - `net.ipv4.tcp_wmem = 4096 65536 16777216`
  - `net.core.rmem_max = 16777216`
  - `net.core.wmem_max = 16777216`
  - `net.ipv4.ip_forward = 1`

---

## 7. The Domino Failure Analysis & Incident Postmortem (Sept 14 Outage)

### Root Cause Sequence
1. **VPS S-UI Core Dead:**
   On the VPS, `sui.service` stopped or crashed. Port 443 was held by the panel socket, but the internal proxy engine was dead (`inactive`).
2. **Hysteria2 (`hy2`) Node Unresponsive:**
   The AX3000T's `proxy-select` group was explicitly set to `"hy2"`. When the VPS core died, `hy2` stopped accepting packets.
3. **Sing-Box Upstream DNS Blocked:**
   The AX3000T's sing-box DNS configuration routes uncached non-.ir domain queries to `"dns-proxy"` (`https://8.8.8.8/dns-query`), which travels over `"detour": "proxy-select"`. Because `proxy-select` was dead, DoH exchanges timed out with:
   `dns: exchange failed for <domain>. IN A: timeout: no recent network activity`
4. **Network-Wide DNS Blackout:**
   Every LAN client uses `192.168.1.1:53` (`dnsmasq`). `dnsmasq` forwards all queries to `127.0.0.1#5354` (sing-box). Since sing-box timed out on every query, **no client in the house could resolve any domain**. Even direct Iranian websites appeared broken because their domain names could not resolve.
5. **Direct ICMP & Raw IP Routing Remained Alive:**
   Pinging `8.8.8.8` from the router succeeded throughout the outage, and `curl http://1.1.1.1/` returned HTTP 301. The cellular link was never down.

### The Fix Applied
1. `ssh vps "systemctl restart sui"` → Restored VPS proxy core and inbounds.
2. `ssh root@192.168.1.1 "/etc/init.d/sing-box restart"` → Cleared wedged DNS resolver state.
3. Switched AX3000T node to `vps-reality` via Clash API:
   `curl -s -X PUT -d '{"name":"vps-reality"}' http://127.0.0.1:9090/proxies/proxy-select`
4. Both proxy socks ports returned HTTP 204 immediately.

---

## 7b. Performance Baseline & Tuning Profile (Sept 15, 2026)

Full measurement log: [`../.scratch/speed-profile-2026-09-15.md`](../.scratch/speed-profile-2026-09-15.md).
Method used: baseline → one controlled change → re-measure. **Never touch tunnel
match parameters (flow/uuid/SNI/short-id) on only one side** — a server-side
`flow: xtls-rprx-vision` edit without the matching client caused a REALITY
handshake mismatch and a household outage; it was reverted.

### Measured baseline (AX3000T, through `vps-reality`, evening peak)

| Metric | Value |
|---|---|
| Download (tunnel) | ~15–16 Mbps |
| Upload (tunnel) | ~5.4 Mbps |
| Idle RTT to VPS | avg 144 ms (RTT floor of the Iran→EU cellular path) |
| RTT under download load | avg 147 ms → **bufferbloat ≈ 0** |
| Radio | MCI 5G NSA, RSRP −74 dBm |

### Durable findings (do not re-learn these the hard way)

1. **SQM/CAKE on `lan4` must stay enabled** (95M↓/25M↑, cake `diffserv4 dual-dsthost nat ack-filter`).
   With SQM off: RTT under load degraded 147→158 ms avg / 235 ms max, while throughput barely moved.
   SQM costs ~0 throughput and buys a flat ping — it is already optimal.
2. **Ping is carrier-bound, not config-bound.** 144 ms idle ≈ the physical RTT of
   the Iran→EU cellular path; nothing in the router stack can go below it.
3. **MCI applies QoS on non-standard TCP ports.** Raw TCP to the VPS on port
   5201 connects then collapses (~1 Mbps, cwnd 1.4 KB) while dport 443 sustains
   15+ Mbps on the identical path. Keep all production traffic on 443.
4. **UDP toward `85.121.124.158` (Carrier Dynamic Filtering & Dedicated Gaming Isolation):**
   MCI cellular uplink dynamically applies carrier-grade firewall rules per IP allocation pool.
   On certain cellular IP pools, UDP port 31800 is blocked, while on others (e.g. pool `37.156.153.x`),
   UDP is fully transparent and `hy2` operates at ~292ms latency with zero packet drops.
   **Architecture Rule:** Because cellular UDP filtering is dynamic, `hy2` must NEVER be placed in the
   general browsing `auto` urltest group (where a UDP block would stall browser tabs and DoH).
   Instead, `hy2` is isolated into the dedicated `gaming` outbound group (`["hy2", "vps-reality"]`)
   for Steam/Valve traffic, where UDP delivers low jitter and packet loss resilience, while seamlessly
   falling back to `vps-reality` TCP if carrier UDP drops.
5. **VPS TCP stack** (`/etc/sysctl.d/99-bbr-buffer-tune.conf`): BBR + `fq`,
   64 MB rmem/wmem, `tcp_fastopen=3`, `tcp_mtu_probing=1`,
   `tcp_slow_start_after_idle=0`. Safe, server-side only; benefits lossy-path throughput.
6. **Measurement tools:** busybox `nc` on OpenWrt lacks half-close (hangs);
   iperf3 3.20↔3.16 cross-version hangs; port 8443 is occupied by `sui` (cdn-ws).
   Use `curl` through SOCKS against `speed.cloudflare.com/__down|__up` instead.
7. **Band-steering (`usteerd`) is forbidden on this router** — SSIDs are split
   (`XI-2G` / `XI-5G`); 802.11v transitions between different SSIDs kick clients
   off Wi-Fi. `usteer` is stopped and disabled; keep it that way unless SSIDs unify.
8. **Re-measure throughput after ~01:00 IRST** — repo history shows MCI is fast at
   night and congested by day; night numbers reveal the true bearer ceiling.

---

## 7c. Postmortem: Cold-Boot Outage After Power Cycle (Sept 16, 2026)

The household power-cycled both routers while re-arranging cables. The network
came back "up" (Wi-Fi associated, DHCP served, ICMP fine) but **all proxied
internet was dead**. This section records the full causal chain and the
recovery playbook so the next power cycle costs 5 minutes, not 2 hours.

### Root-Cause Chain (in order)

1. **Stale clock on AX3000T (THE root cause).** The board has no RTC; on cold
   boot OpenWrt's `sysfixtime` restores the *last saved* time, which was ~20 h
   in the past. REALITY authenticates using timestamps (tolerance ≈ 2 min), so
   the VPS rejected every handshake with
   `inbound/vless: TLS handshake: REALITY: processed invalid connection`.
   Any delay/handshake failure that survives config verification on BOTH sides
   — check `date -u` on client and server FIRST.
2. **Watchdog fail-open amplified it.** `proxy-watchdog` saw 5×30 s of failed
   probes and engaged fail-open: `axproxy` flushed, `dnsmasq` repointed to
   `192.168.70.1`. Foreign internet dead by design until recovery.
3. **DNS caches got poisoned during fail-open.** While dnsmasq pointed at the
   ISP path and sing-box answered through the broken tunnel, poisoned A records
   (`0.1.0.1` — MCI's block-page IP) were cached. **Caches survive the fix**;
   clean tunnel + stale cache = "tunnel works but sites don't open".
4. **X28 boot wedge.** After cold boot X28's daemon stack (mihomo + 46-node
   rescue-pool health checks + v2raya + a dozen supervision loops) drove load
   above 3.5: dropbear stopped answering (banner timeout) and the control plane
   starved even though the kernel forwarding plane still worked. A controlled
   reboot cleared it.
5. **Laptop-side false alarms.** WSL2 mirrored networking intercepts/breaks
   port-53 traffic and mirrors Windows route metrics into WSL — WSL DNS tests
   returned `0.1.0.1` while router-local `nslookup` returned clean answers at
   the same moment. Never diagnose DNS from WSL; use router-local queries or a
   real Wi-Fi client.

### Recovery Playbook (executed, worked end-to-end)

```bash
# 0. Clock FIRST — fixes REALITY instantly if skew was the cause:
VPSNOW=$(ssh vps 'date -u +%s')
sshpass -p "xirouter123" ssh root@192.168.1.1 "date -u -s @$VPSNOW"   # busybox needs @epoch
ssh root@192.168.1.1 "/etc/init.d/sing-box restart"

# 1. If still fail-open, ride a healthy path manually (X28 mihomo is independent):
ssh root@192.168.1.1 "curl -s -X PUT -d '{\"name\":\"via-x28\"}' http://127.0.0.1:9090/proxies/proxy-select"
#    (PUT /proxies/auto is refused — auto is a URLTest group, only Selector accepts PUT.)

# 2. Flush BOTH DNS caches after the tunnel is verified (204 probe):
ssh root@192.168.1.1 "/etc/init.d/sing-box stop; rm -f /etc/sing-box/cache.db; \
                      /etc/init.d/sing-box start; /etc/init.d/dnsmasq restart"

# 3. Re-apply transparent interception if axproxy is missing:
ssh root@192.168.1.1 "nft list table inet axproxy >/dev/null 2>&1 || sh /etc/axproxy.sh"

# 4. Only if X28 control plane is wedged (load >3, dropbear banner timeout):
#    controlled reboot via telnet :23 (NOT power pull — /tmp state + boot race return).
```

Then verify from a LAN client, not the router (router OUTPUT bypasses the
transparent path): `curl -s -o /dev/null -w '%{http_code}' https://www.youtube.com`.

### Permanent Fixes Applied (Sept 16)

1. **REALITY Clock Guard** — `/etc/rc.local` on AX3000T: background one-shot
   `ntpd -q` loop (12×10 s, direct UDP 123, tunnel-independent) with a
   `clock-guard` syslog marker. Every future cold boot self-heals the clock
   before traffic matters.
2. **sing-box DNS detour** — `dns-proxy.detour` changed `auto` → `proxy-select`
   on AX3000T (and in `router/sing-box-config.json`). DNS now rides the
   human-controlled selector; a wedged `auto` can no longer blackhole DNS.
3. **Windows/WSL laptop fixes** — Ethernet interface metric pinned to 9999 (LAN
   never hijacks the default route from the hotspot) + persistent routes
   `192.168.70.0/24` and `192.168.1.0/24` via `192.168.1.1` bound to the
   Ethernet interface (`IF 22`). See §3 Laptop Hotspot Triage Protocol.
4. **Runbook addition** — §8 step 0 now starts with the clock check.

### Durable Lessons

- `date -u` on BOTH endpoints before any REALITY/timeout debugging. Cheapest test.
- "Connection works from router, fails from LAN" (or vice versa) tells you which
  layer to inspect: router OUTPUT is never transparent-proxied; LAN traffic is.
- `0.1.0.1` in any DNS answer = MCI poisoning reached that cache. Flush caches
  after every fail-open episode, not just after the tunnel heals.
- dnsmasq answer path on AX3000T: LAN → dnsmasq:53 → sing-box:5354 → DoH. Poison
  can sit in either cache; test sing-box directly with
  `nslookup -port=5354 <domain> 127.0.0.1` to bisect.
- WSL2 mirrored networking cannot be trusted for port-53 diagnostics, and
  Windows route changes mirror into WSL instantly (incl. wrong-iface routes).

---

## 8. 60-Second Troubleshooting & Health Check Runbook

If anyone in the house reports "No Internet", run this single diagnostic pipeline from your laptop:

```bash
# 0. CLOCK CHECK — do this first, especially after ANY power outage / cold boot.
#    REALITY rejects every handshake while client/server clock skew > ~2 min,
#    and a RTC-less OpenWrt board boots with a stale sysfixtime.
echo "AX3K clock: $(sshpass -p 'xirouter123' ssh root@192.168.1.1 'date -u +%s')  |  VPS clock: $(ssh vps 'date -u +%s')"
#    Skew > 120 s → fix per §7c playbook step 0 (date -u -s @epoch), then restart sing-box.

# 1. Quick probe to AX3000T (DNS, Direct HTTP, Proxy SOCKS):
sshpass -p "xirouter123" ssh root@192.168.1.1 "
echo '=== AX3000T HEALTH CHECK ==='
echo -n 'DNS Resolution: '
nslookup google.com 127.0.0.1 >/dev/null 2>&1 && echo 'OK' || echo 'FAIL (DNS wedged)'
echo -n 'Direct Internet: '
curl -sm5 -o /dev/null -w '%{http_code}\n' http://connectivitycheck.gstatic.com/generate_204
echo -n 'Proxy via SOCKS: '
curl -sm8 -x socks5h://127.0.0.1:1080 -o /dev/null -w '%{http_code}\n' http://www.gstatic.com/generate_204
echo -n 'Active Node: '
curl -s http://127.0.0.1:9090/proxies/proxy-select | grep -o '\"now\":[^,]*'
"

# 2. If Proxy via SOCKS is 000:
# Check VPS S-UI:
ssh vps "systemctl is-active sui"

# Restart VPS core if inactive or wedged:
ssh vps "systemctl restart sui"

# Switch AX3000T to vps-reality:
sshpass -p "xirouter123" ssh root@192.168.1.1 "
curl -s -X PUT -d '{\"name\":\"vps-reality\"}' http://127.0.0.1:9090/proxies/proxy-select
/etc/init.d/sing-box restart
"

# 2b. If tunnel is UP (SOCKS 204) but sites still don't open → flush poisoned DNS
# caches (every fail-open episode leaves 0.1.0.1 / 10.10.34.35 records behind):
sshpass -p "xirouter123" ssh root@192.168.1.1 "
/etc/init.d/sing-box stop; rm -f /etc/sing-box/cache.db; /etc/init.d/sing-box start
/etc/init.d/dnsmasq restart
"

# 2c. If transparent interception is missing (direct works, proxied doesn't):
sshpass -p "xirouter123" ssh root@192.168.1.1 "sh /etc/axproxy.sh"

# 2d. If X28 control plane is wedged (load >3, dropbear banner timeout):
# controlled reboot via telnet :23 — never a power pull (returns /tmp boot race).

# 3. Emergency Fail-Open (Direct Internet without VPN):
# If the VPS is permanently unreachable and family needs immediate internet:
sshpass -p "xirouter123" ssh root@192.168.1.1 "
# Point dnsmasq directly to X28 cellular DNS:
uci -q delete dhcp.@dnsmasq[0].server
uci add_list dhcp.@dnsmasq[0].server='192.168.70.1'
uci commit dhcp
/etc/init.d/dnsmasq restart
# Stop transparent proxy interception:
nft delete table inet axproxy 2>/dev/null || true
"
```

---

## 9. Disaster Recovery & Unbricking Reference (TFTP & Factory Partition Map)

### 9.1. Emergency TFTP Recovery (AX3000T)
1. Laptop static IP: `192.168.31.100` (Subnet: `255.255.255.0`).
2. Server directory: `C:\Users\Public\axtftp\`. Payload: `C0A81F02.img` (Stock firmware 1.0.98).
3. Connect cable to Port 2 (`lan2`) or Port 3 (`lan3`).
4. Hold the reset button while inserting power; keep holding for 10 seconds until the orange LED flashes rapidly (~5/s).
5. Router pulls image via TFTP, flashes flash memory, and boots stock firmware at `192.168.31.1` in ~4 minutes.

### 9.2. Automated OpenWrt Installation from Stock
```powershell
powershell -ExecutionPolicy Bypass -File C:\Users\Public\axtftp\flash-final2.ps1
```

### 9.3. Flash Memory Partition Archives
Archived in `C:\Users\Public\axtftp\backup\`:

| Filename | Size | Partition Name | Purpose |
|---|---|---|---|
| `Factory.bin` | 2,097,152 bytes (2 MB) | `/dev/mtd4` (`Factory`) | **CRITICAL: Factory RF calibration & hardware MAC** |
| `Bdata.bin` | 262,144 bytes (256 KB) | `/dev/mtd3` (`Bdata`) | Board SKU & serial data |
| `Nvram.bin` | 262,144 bytes (256 KB) | `/dev/mtd2` (`Nvram`) | Bootloader environment |
| `BL2.bin` | 1,048,576 bytes (1 MB) | `/dev/mtd1` (`BL2`) | Second-stage bootloader |
| `FIP.bin` | 2,097,152 bytes (2 MB) | `/dev/mtd5` (`FIP`) | U-Boot & ARM Trusted Firmware |
| `KF.bin` | 262,144 bytes (256 KB) | `/dev/mtd12` (`KF`) | Stock vendor encryption keys |

---

## 10. Deep Architectural Evolution & Resilient Subsystems (Rounds 1–4)

To achieve maximum uptime, eliminate shell friction, and ensure complete testability without mocks, the network software stack was refactored from fragmented procedural scripts into deep architectural modules with clean seams.

### 10.1. Proxy Watchdog 5-State Machine (`router/proxy-watchdog.sh`)
- **Location:** AX3000T (`/usr/sbin/proxy-watchdog.sh`), managed by procd service `/etc/init.d/proxy-watchdog`.
- **State Space:**
  - `HEALTHY`: Both domestic and circumvention links operational. Active probing occurs every 30s.
  - `DEGRADED`: Latency threshold exceeded or soft drops observed; prepares quality rotation.
  - `ROTATING`: Transparently cycles egress nodes via sing-box Clash API (:9090).
  - `FAILOPEN`: Egress dead for ≥90s. Deletes nftables interception table (`nft delete table inet axproxy`) and routes all LAN DNS to X28 cellular upstream (`192.168.70.1`). Direct domestic internet stays 100% alive.
  - `RECOVERING`: Egress restored for ≥60s. Reinstates nftables transparent proxy rules and restores clean upstream DNS.
- **Zero-Reboot Guarantee:** The watchdog NEVER issues a reboot command. All failures are handled through network layer state transitions.
- **Test Seam:** Fully testable with decoupled flags (`--next`, `--qrotate`, `--failback`, `--escalate`, `--state`).

### 10.2. Telegram Bot Command Dispatcher (`router/x28/bot-dispatch.sh`)
- **Location:** X28 (`/data/proxy/bot-dispatch.sh`), called by `@xirouterbot` (`x28-bot.sh`).
- **Decoupled Architecture:** Completely separates network transport (Telegram polling loop `getUpdates`, HTTP timeouts, offset commits) from permission checks and action execution.
- **Structured Output Registers:** Emits discrete action tokens (`send_html`, `edit_panel`, `send_photo`, `switch_carrier`) parsed by caller.
- **Role-Based Access Control:** Distinguishes Admin (Parsa) vs household members for sensitive actions (reboot, carrier switch, quarantine).

### 10.3. Unified Device Trust Model (`router/device-registry.sh`)
- **Location:** AX3000T (`/root/device-registry.sh`).
- **Domain Trust Levels:**
  - `Blocked`: Drops all L3/L4 traffic in nftables quarantine set (`quarantine_v4`).
  - `Guest`: Constrained to guest subnet (`192.168.3.0/24`) with isolated routing.
  - `Unknown`: Unregistered device observed on LAN; alerts admin via Telegram.
  - `Known`: Registered device with hostname/MAC association.
  - `Trusted`: Full access with priority QoS classification.
- **Atomic Persistence:** Unifies `/etc/dnsmasq.conf`, `/etc/ethers`, and quarantine nftables state with atomic write swaps.

### 10.4. Structured Router API Response Pipeline (`router/routerapi.sh`, `router/routerapi_lib.sh`)
- **Location:** AX3000T (`/www/cgi-bin/routerapi.sh`, `/root/routerapi_lib.sh`).
- **In-Memory Buffer:** Eliminates scraping temporary files and stdout markers (`@@STATUS:NNN`).
- **POSIX Robustness:** Uses native parameter expansion `${output##*@@STATUS:}` within the parent execution context, guaranteeing RFC-compliant HTTP status codes and JSON formatting.

### 10.5. Cellular Gateway & Reselection Seam (`router/x28link.sh`, `router/x28reselect.sh`)
- **Location:** AX3000T (`/root/x28link.sh`, `/root/x28reselect.sh`) & X28 (`/data/proxy/modem-supervisor.sh`).
- **Decoupled Link Monitoring:** AX3000T `x28watch.sh` polls X28 link state via `/root/x28link.sh` every 5 minutes.
- **Anti-Flap Guard:** Enforces 600s cooldown between carrier switches and a storm guard cap of max 3 switches per hour.
- **Dual-Path Execution:** Primary path uses authenticated SSH to trigger `modem-supervisor.sh switch 43211` on X28; automatic fallback to vendor HTTP API (`http://192.168.70.1/cgi-bin/http.cgi`, cmd 228).
- **BusyBox Compatibility:** Incorporates custom `run_with_timeout` to maintain non-blocking behavior on minimal BusyBox builds lacking the `timeout` binary.

### 10.6. Smart TV & IPTV Ingress Gateway (`router/media-gateway.sh`)
- **Location:** AX3000T (`/usr/sbin/media-gateway.sh`, `/www/cgi-bin/media`, `/www/cgi-bin/stream`).
- **Samsung Q70C Lifecycle:** Sends WOL magic packets (`etherwake -i br-lan c8:12:0b:32:7c:f2`) and polls Tizen OS REST API (`http://192.168.1.105:8001/api/v2/`).
- **Telewebion Edge Cache:** Resolves dynamic live CDN edge URLs and caches with a 45-second TTL to eliminate HTTP redirect stalls.
- **Tizen 9.0 Integer Overflow Mitigation:** Live HLS manifests from Iranian national broadcasters (IRINN, Varzesh, etc.) emit 16-digit 64-bit `#EXT-X-MEDIA-SEQUENCE` timestamps (e.g. `1789476208605550`). Tizen OS 9.0 AVPlay player treats sequence numbers as 32-bit signed integers, crashing upon playback. `media-gateway.sh` rewrites sequence numbers down to 9 digits in real-time via `sed -E 's/EXT-X-MEDIA-SEQUENCE:[0-9]{7}([0-9]{9})/EXT-X-MEDIA-SEQUENCE:\1/'`.
- **Adaptive Master Playlist:** Generates master M3U8 defining 480p, 720p, and 1080p bandwidth profiles.

### 10.7. Bulk Rescue Engine (`router/x28/rescue-engine.sh`)
- **Location:** X28 (`/data/proxy/rescue-engine.sh`).
- **O(1) Bulk Aliveness:** Replaced legacy N+1 loop (`for m in $members; do curl ...`) with a single bulk query to Mihomo `/proxies` API evaluated in `jq`, reducing health check latency from ~30s to ~50ms.
- **Protocol Conversion:** Converts VMess, VLESS, Reality, Trojan, Shadowsocks, Hysteria2, Tuic, and Juicity URIs into Mihomo provider configuration via strict awk parser.
- **Hysteresis State Machine:** Promotes traffic to public rescue pool after ≥4 consecutive minutes of owned VPS failure (requires ≥1 alive rescue node); automatically demotes back to owned VPS after 10 consecutive minutes of stable owned aliveness.

### 10.8. Telemetry Aggregation & Network Health Engine (`router/telemetry-engine.sh`)
- **Location:** AX3000T (`/root/telemetry-engine.sh`), scheduled hourly in crontab.
- **Composite Network Health Score (0–100):** Computed using a declarative weight matrix:
  1. *Cellular Link Quality (25 pts):* RSRP > -80 dBm (25), > -90 dBm (20), > -100 dBm (12), ≤ -101 dBm (5); -10 penalty if drifted from preferred MCI PLMN.
  2. *Proxy / Egress Health (35 pts):* Watchdog healthy (35), degraded (20), failopen/direct (10), dead (0).
  3. *DNS Subsystem Quality (20 pts):* Latency < 50ms (10), < 150ms (6), ≥ 150ms (2); query failure rate ≤ 2% (10), ≤ 5% (6), > 5% (0).
  4. *Compute & Memory (20 pts):* Load 1m < 1.0 (10), < 2.0 (6), ≥ 2.0 (2); RAM used < 75% (10), < 90% (6), ≥ 90% (2).
- **Rolling History Ledger:** Appends JSON snapshots to `/etc/telemetry/hourly.jsonl`, pruned to 8760 entries (1 year).

---

## 11. Mobile vs. Router Circumvention Triage (Phone Failure Analysis)

### 11.1. Why Mobile Devices Fail While Routers Stay Connected
When users report: *"I gave the exact same configs to a friend and none work on their phone, but the home router is connected 24/7"*, this is caused by four architectural discrepancies between mobile operating systems and Linux router engines:

1. **Baseband MTU Clamping & TLS Packet Fragmentation:**
   - Cellular baseband modems (Irancell/MCI/Rightel LTE/5G) enforce Path MTU down to **1420** or **1380** bytes (due to GTP-U cellular encapsulation tunnels).
   - On the AX3000T router, iptables/nftables automatically clamps TCP MSS (`tcp flags syn tcp option maxseg size set rt mtu`).
   - On Android and iOS phones, VPN clients often default to MTU **1500**. When sending the initial TLS Client Hello with Reality certificates, the packet exceeds 1420 bytes, gets fragmented, and DPI firewalls at the cellular edge drop fragmented TLS Client Hello packets unconditionally.
   - **Fix:** In mobile clients (v2rayNG / Sing-Box / Streisand), set MTU explicitly to **1360** or **1280**.

2. **Android "Private DNS" (DoT Port 853) Deadlock:**
   - Android 9+ enables "Private DNS" by default in `Automatic` mode.
   - When connecting to cellular data, Android attempts to resolve domains using DNS-over-TLS (DoT) on port 853 to `dns.google` or Cloudflare.
   - Iranian cellular operators reset or blackhole port 853 TCP packets.
   - Because the phone cannot resolve the VPS hostname before the VPN handshake completes, the connection times out with `resolve error` or `connection refused`.
   - **Fix:** On the phone, navigate to **Settings -> Network & Internet -> Private DNS** and select **OFF**.

3. **Cellular UDP Throttling on Hysteria 2:**
   - MCI and Irancell enforce heavy QoS throttling or drop UDP packets exceeding 50 packets/second on non-standard ports.
   - On AX3000T, Hysteria2 works because UDP packet bursts are smoothed by CAKE SQM QoS and the router maintains continuous socket keepalive.
   - On mobile, carrier DPI recognizes raw QUIC handshakes and resets them within seconds unless **Salamander Obfuscation** is strictly enabled.
   - **Fix:** For mobile users on mobile data, prioritize **VLESS-Reality over TCP port 443** rather than Hysteria2 UDP.

4. **TLS Client Hello Fingerprint Mismatch (JA3/JA4):**
   - Outdated mobile clients (older v2rayNG or generic Xray forks) send outdated TLS ciphers or Golang standard crypto fingerprints that Iranian ISP DPI blocks.
   - **Fix:** Ensure mobile client is configured with `fingerprint: "chrome"` or `fingerprint: "firefox"`.

### 11.2. Mobile-Optimized VLESS-Reality Configuration Profile
To share a connection that works reliably on mobile phones (MCI, Irancell, and Rightel):

```json
{
  "type": "vless",
  "tag": "proxy-reality-mobile",
  "server": "85.121.124.158",
  "server_port": 443,
  "uuid": "7a353606-d24a-4e20-94cb-5ffea85f1c99",
  "tls": {
    "enabled": true,
    "server_name": "www.bing.com",
    "utls": {
      "enabled": true,
      "fingerprint": "chrome"
    },
    "reality": {
      "enabled": true,
      "public_key": "x0W1f6r7p9Q2y3Z4a5B6c7D8e9F0g1H2i3J4k5L6m7N",
      "short_id": "0123456789abcdef"
    }
  },
  "packet_encoding": "xudp"
}
```

### 11.3. Friend Setup 4-Step Checklist
1. **Turn Private DNS OFF:** Phone Settings -> Network -> Private DNS -> Off.
2. **Use VLESS-Reality 443:** Do not use UDP/Hysteria on mobile data during high-filtering hours.
3. **Set App MTU to 1360:** In v2rayNG / Streisand / Sing-Box settings, change MTU from 1500 to 1360.
4. **Select Chrome Fingerprint:** Ensure TLS emulation is set to `chrome` (never `random` or `none`).
