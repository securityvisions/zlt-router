# Home Network Architecture & Operations Manual — Complete Zero-to-One Reference

**Last Updated:** September 2026  
**Hardware Ecosystem:** Xiaomi Mi Router AX3000T (`192.168.1.1`) + ZLT X28 5G CPE (`192.168.70.1`) + Remote VPS (`85.121.124.158`)

---

## 1. Executive Summary & Top-Level Architecture

The home network is a robust, self-healing, dual-router appliance built to survive power cuts, cable swapping, and regional censorship/DNS poisoning without breaking or requiring manual intervention.

```
                         Internet (MCI 5G NSA / Rightel 4G)
                                         │
┌────────────────────────────────────────▼────────────────────────────────────────┐
│  ZLT X28 (192.168.70.1) — Cellular Edge, Control Plane & Standby Gateway        │
│  · MediaTek MT6890 5G CPE (4× A55, 643 MB RAM)                                  │
│  · Samantel SIM (PLMN 43211 MCI 5G NSA, fallback 43220 Rightel)                │
│  · Mihomo Proxy Engine (SOCKS :1080, Redirect :12345)                          │
│  · Independent Backup Wi-Fi: ZL-5G / ZL-2.4G                                    │
│  · Telegram Bot (@xirouterbot) + Web Dashboard (:8080)                         │
│  · DNS: dnsmasq (:53) ──► mihomo DoH (:5353) [Poisoned ISP DNS blocked]        │
└────────────────────────────────────────┬────────────────────────────────────────┘
                                         │ Single Ethernet Cable (ANY port to ANY port)
┌────────────────────────────────────────▼────────────────────────────────────────┐
│  Xiaomi AX3000T (192.168.1.1) — Primary House Router & Dedicated Proxy Core    │
│  · MediaTek Filogic 820 MT7981B (2× A53, 256 MB RAM)                           │
│  · Clean OpenWrt 25.12.5 Mainline (Linux 6.12.94, apk package manager)          │
│  · Auto-sensing WAN detection (wan-detector: auto-binds whichever port has X28) │
│  · Primary High-Performance Wi-Fi 6: XI-5G & XI-2G (WPA2-PSK: xirouter123)     │
│  · Sing-Box Proxy Engine (Redirect :12345, SOCKS :1080, VLESS+Reality / Hy2)   │
│  · Transparent nftables interception for all Wi-Fi / LAN clients               │
│  · Domestic Iran split-routing (geosite-ir, geoip-ir -> DIRECT)                │
│  · CAKE SQM on active WAN port (50 Mbps down / 15 Mbps up)                      │
│  · U-Boot Bootcount Guard (/etc/init.d/bootcount: zero bricking risk)           │
│  · ZERO automatic reboots (100% immune to power outages & boot order races)     │
└─────────────────────────────────────────────────────────────────────────────────┘
```

---

## 2. Master Credentials & Network Map

### 2.1. Primary House Router — Xiaomi AX3000T

| Parameter | Value | Notes |
|---|---|---|
| **Hardware / Model** | Xiaomi AX3000T (RD03, MT7981B, 256 MB DDR3) | Chinese retail version |
| **Operating System** | OpenWrt 25.12.5 (r33051-f5dae5ece4) | Clean mainline, apk package manager |
| **LAN IP Address** | `192.168.1.1` (Subnet: `255.255.255.0`) | Default gateway for house clients |
| **DHCP Server Range** | `192.168.1.100` – `192.168.1.249` (Lease: 12h) | Serves wired LAN & Wi-Fi clients |
| **SSH Access** | `ssh root@192.168.1.1` (Port 22) | Dropbear SSH daemon |
| **Root / Admin Password** | `xirouter123` | Used for SSH and LuCI Web UI |
| **LuCI Web Admin** | `http://192.168.1.1/` (Port 80 / 443) | uhttpd web server |
| **Wi-Fi 5GHz (Wi-Fi 6)** | SSID: **`XI-5G`** (Channel 36, 80 MHz, HE-MCS 11) | WPA2-PSK: `xirouter123` |
| **Wi-Fi 2.4GHz** | SSID: **`XI-2G`** (Channel 1, 20 MHz) | WPA2-PSK: `xirouter123` |
| **WAN Uplink Mode** | Static: IP `192.168.70.2`, Gateway `192.168.70.1` | Assigned dynamically to active port |
| **Active WAN Port** | Auto-detected (currently physical port `lan4`) | Managed by `wan-detector` daemon |
| **Physical Port Layout** | Left to Right: Port 1 (`wan`), Port 2 (`lan2`), Port 3 (`lan3`), Port 4 (`lan4`) | Any port can accept the uplink cable |
| **SSH Host Key (ED25519)**| `SHA256:967334DLzpKVa6ZZ86gaHOACVZ7/iV9E6YtMDp+WQkI` | Stored in PuTTY / known_hosts |

---

### 2.2. WAN Gateway & Modem — ZLT X28

| Parameter | Value | Notes |
|---|---|---|
| **Hardware / Model** | Tozed ZLT X28 (MediaTek MT6890 5G, 643 MB RAM) | 4G/5G Cellular Gateway |
| **Operating System** | OpenWrt 19.07-SNAPSHOT (Kernel 4.19.205) | Vendor build, BusyBox 1.30.1 |
| **LAN IP Address** | `192.168.70.1` (Subnet: `255.255.255.0`) | Gateway for AX3000T & ZL clients |
| **DHCP Server Range** | `192.168.70.100` – `192.168.70.200` | Excludes static `192.168.70.2` (AX3000T) |
| **Telnet Break-Glass** | `nc 192.168.70.1 23` | Root shell, no password, LAN only |
| **Vendor Web UI** | `http://192.168.70.1/` (Port 80 / 443) | Username: `admin`, Password: `admin` |
| **NOC Web Dashboard** | `http://192.168.70.1:8080/` | Custom lightweight dark-mode dashboard |
| **Wi-Fi 5GHz (Backup)** | SSID: **`ZL-5G`** | WPA2-PSK (Independent fallback network) |
| **Wi-Fi 2.4GHz (Backup)**| SSID: **`ZL-2.4G`** | WPA2-PSK |
| **Cellular Connection** | Samantel SIM (MCI 5G NSA, PLMN 43211) | Fallback: Rightel 4G (PLMN 43220) |
| **Telegram Bot** | `@xirouterbot` | Remote status, billing, alerts |
| **Proxy Engine** | `mihomo` (SOCKS: `192.168.70.1:1080`, Redir: `:12345`) | Dedicated backup proxy |

---

### 2.3. Remote Proxy Origin — VPS

| Parameter | Value | Notes |
|---|---|---|
| **Server IPv4** | `85.121.124.158` | Debian-class VPS |
| **s-ui Admin Panel** | `http://85.121.124.158:2095/` | Web panel for proxy management |
| **s-ui Credentials** | Username: `suiadmin`, Password: `Sui-697ebba6619cf922` | Stored in `/etc/sui-heal.conf` |
| **Subscription URL** | `http://85.121.124.158:2096/sub/` | Subscription endpoint |
| **VLESS+Reality Node** | Port: `443`, UUID: `5ee543a7-9a11-4d0d-b3e6-153945539f60` | SNI: `www.bing.com`, Fingerprint: `chrome` |
| **Reality Public Key** | `fIZg5mhL-DlLT03aBciQw94x6hPOe2_T6ivsRHRyMWA` | Short ID: `7fa7e3ce4165cba3` |
| **Hysteria2 Node** | Port: `31800`, Password: `p4DyJIAuyp` | Obfs: `salamander`, Pass: `bwne4pabf0tzt00f` |
| **CDN WebSocket Node** | Server: `188.114.98.0:443`, Host/SNI: `cdn.dmbz.ir` | Path: `/v1/status` |
| **Babaii Fallback Node** | Server: `216.45.52.132:23993` | Vision flow (currently down) |

---

## 3. How the Zero-Headache Resilience Features Work

### 3.1. Auto-Sensing WAN Port (`wan-detector`)
On the AX3000T, you no longer need to worry about which port to plug the cable into:
- The daemon `/usr/sbin/wan-detector` runs under `procd` supervision.
- Every 10 seconds, it inspects link carriers across `wan`, `lan2`, `lan3`, and `lan4`.
- When a cable is detected, it runs an instant Layer 2 ARP probe for the X28's MAC address (`98:a9:42:6b:67:b8`) on that specific port.
- The port that answers is dynamically bound as `network.wan.device` (`192.168.70.2`).
- The other three physical ports are automatically bridged into `network.@device[0].ports` (`br-lan`).
- The reload is applied seamlessly via `ubus call network reload` without dropping Wi-Fi or restarting local LAN DHCP.

### 3.2. Power-Cut & Boot-Race Immunity
When power drops and restores:
- **AX3000T boot time:** ~45 seconds.
- **X28 boot time:** ~150–180 seconds (cellular baseband negotiation takes ~2.5 minutes).
- **The Solution:**
  1. **Static WAN IP:** AX3000T has static IP `192.168.70.2` on WAN. It never sends DHCP discovers, never times out, and never goes into backoff. The instant X28 finishes booting, packets flow immediately.
  2. **Zero Auto-Reboots:** No script on the AX3000T will ever issue a reboot command based on connectivity failure.
  3. **Bootcount Guard:** `/etc/init.d/bootcount` unconditionally zeroes out `flag_try_sys1_failed=0` and `flag_try_sys2_failed=0` in nvram on every boot, permanently neutralizing the U-Boot bootloop / partition-flip flaw that caused the original brick.

### 3.3. Independent Dual-VPN Architecture
- **AX3000T (House Traffic):** Runs local `sing-box` 1.13.18. Transparently redirects LAN/Wi-Fi TCP ports (80, 443, etc.) to `:12345`.
  - Domestic Iranian websites (`geosite-ir`, `geoip-ir`) bypass the tunnel and connect direct in **0.16s**.
  - Foreign / censored platforms (YouTube, Google, Twitter, Telegram, Instagram) route through the VPS in **0.5s**.
  - Local management traffic (`192.168.0.0/16`, `10.0.0.0/8`, `172.16.0.0/12`) is strictly exempted via `/etc/axproxy.nft` so LuCI and SSH are never blocked.
- **X28 (Fallback Traffic):** Runs its own `mihomo` proxy.
  - `tproxy-enable.sh` explicitly bypasses `192.168.70.2` (`RETURN`) to prevent double-proxying or re-encryption.
  - Clients connected to `ZL-5G` use the X28's proxy independently.
  - If either router is rebooted or turned off, the other router's clients continue browsing with zero disruption.

### 3.4. Permanent DNS Poisoning Neutralization
In Iran, local telecom DNS (`10.201.112.252` / `217.218.127.127`) poisons censored domains to `10.10.34.35`:
- On the X28, `lan_mgr` previously regenerated `/tmp/dnsmasq_resolv.conf` containing the telecom IPs, racing against clean DNS.
- **The Fix:** `/data/proxy/dns-fix.sh` permanently comments out `resolv-file` in `dnsmasq.conf` in tunnel mode. `dnsmasq` queries **only** clean DoH via `127.0.0.1#5353`.
- `dns-fix.sh` now uses seamless `kill -HUP` instead of `pkill -9`, permanently eliminating the 64-second DHCP restart crash-loop.

---

## 4. Disaster Recovery & Unbricking Guide

If the AX3000T is ever misconfigured, flashed incorrectly, or reset, follow these exact verified steps to restore it:

### 4.1. The Emergency Recovery Dance (TFTP Restore)
1. Set the laptop's Ethernet to static IP `192.168.31.100` (Subnet: `255.255.255.0`).
2. Run the TFTP/DHCP server from `C:\Users\Public\axtftp\`:
   - Firmware payload file must be named: `C0A81F02.img` (MD5 of stock 1.0.98: `3e41c586ccaf5eb43e9eb8ffcf048abd`).
   - Run `python C:\Users\Public\axtftp\ax-server.py`.
3. Plug the Ethernet cable into physical port 2 (`lan2`) or port 3 (`lan3`).
4. **Unplug power.**
5. **Press and HOLD the reset button.**
6. **Plug power in while holding reset.**
7. Hold for ~10 seconds until the orange LED **blinks rapidly** (~5/s), then release.
8. The router pulls `C0A81F02.img` over TFTP in ~4 seconds and writes flash (steady orange).
9. Wait ~4–5 minutes until the **BLUE LED flashes rapidly**.
10. Power-cycle once. The router boots official stock firmware at `192.168.31.1`.

### 4.2. OpenWrt Re-Installation from Stock (API RCE Method)
1. Complete the stock offline wizard (continue without cable, set admin password to `xirouter123`).
2. Connect laptop Wi-Fi to the router's SSID (`Xiaomi_7A40` / `rd03_minet_...`).
3. Run the automated master script:
   ```powershell
   powershell -ExecutionPolicy Bypass -File C:\Users\Public\axtftp\flash-final2.ps1
   ```
4. The script logs in, executes the quote-free dropbear gate fix:
   ```sh
   sed -i s/release/debug/g /etc/init.d/dropbear
   /etc/init.d/dropbear enable
   /etc/init.d/dropbear restart
   /etc/init.d/dropbear start
   passwd -d root
   ```
5. It backs up all partitions, checks `/proc/cmdline`, writes `openwrt-25.12.5-initramfs-factory.ubi` to the inactive slot via `ubiformat`, flips nvram boot flags, reboots into initramfs, and applies `openwrt-25.12.5-squashfs-sysupgrade.bin`.
6. Result: Clean OpenWrt 25.12.5 at `192.168.1.1`.

### 4.3. Restoring the Full Configuration Snapshot
A complete verified configuration snapshot is stored on the laptop:
- File: `C:\Users\Public\axtftp\backup\ax3000t-resilience-final.tar.gz` (38.6 KB).
- To restore everything in 30 seconds:
  ```bash
  scp ax3000t-resilience-final.tar.gz root@192.168.1.1:/tmp/
  ssh root@192.168.1.1 "sysupgrade -r /tmp/ax3000t-resilience-final.tar.gz"
  ```
  The router restores all network configurations, wireless SSIDs, firewall rules, sing-box configs, and auto-WAN services, then reboots into the verified working state.

### 4.4. Permanent Hardware Partition Backups
All original factory calibration and hardware partitions extracted from the flash NAND chip are archived in `C:\Users\Public\axtftp\backup\`:

| Filename | Size | Partition Name | Criticality |
|---|---|---|---|
| `Factory.bin` | 2,097,152 bytes (2 MB) | `/dev/mtd4` (`Factory`) | **CRITICAL — Irreplaceable RF calibration & factory MAC** |
| `Bdata.bin` | 262,144 bytes (256 KB) | `/dev/mtd3` (`Bdata`) | Board metadata & SKU configuration |
| `Nvram.bin` | 262,144 bytes (256 KB) | `/dev/mtd2` (`Nvram`) | Stock bootloader environment |
| `BL2.bin` | 1,048,576 bytes (1 MB) | `/dev/mtd1` (`BL2`) | Second-stage bootloader |
| `FIP.bin` | 2,097,152 bytes (2 MB) | `/dev/mtd5` (`FIP`) | ARM Trusted Firmware & U-Boot |
| `KF.bin` | 262,144 bytes (256 KB) | `/dev/mtd12` (`KF`) | Vendor crypto credentials |

---

## 5. Physical Living Room Setup Instructions

When moving both devices to the living room:

1. Place both devices near your desired spot.
2. Connect **ONE Ethernet cable** between the two routers:
   - One end into **any LAN port on the X28**.
   - The other end into **ANY port on the AX3000T** (port 1, 2, 3, or 4 — `wan-detector` automatically configures it).
3. Plug power into both routers (in any order, at the exact same time).
4. Wait ~2.5 minutes for the X28 to establish cellular 5G.
5. Done!
   - House Wi-Fi: Connect to **`XI-5G`** or **`XI-2G`** (Password: `xirouter123`).
   - Backup Wi-Fi: Connect to **`ZL-5G`** or **`ZL-2.4G`**.
   - Ethernet ports on AX3000T: Plug TVs, consoles, or PCs into any of the 3 remaining ports for full gigabit speed and VPN bypass.
