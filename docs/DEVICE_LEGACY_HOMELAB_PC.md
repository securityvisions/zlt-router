# Dedicated HomeLab Server (Legacy PC — Pentium G2030 / H61M-K) — Architecture & Hardware Reference

This document is the canonical reference for the repurposed legacy desktop PC on the home network, its complete hardware specifications, thermal and acoustic zeroing optimizations, and its integration role as a 24/7 headless home server.

---

## 1. Device Profile & Hardware Specifications

| Component | Specification | Details & Operational State |
|---|---|---|
| **System Role** | 24/7 Silent HomeLab Server | Headless Docker, Media Server, Proxy Crypto Offload |
| **CPU** | Intel Pentium G2030 | Ivy Bridge (22nm), LGA 1155, 2 Cores / 2 Threads @ 3.00 GHz, 3MB SmartCache, 55W TDP |
| **Integrated GPU (iGPU)** | Intel HD Graphics for 3rd Gen Intel Processors | Base 650 MHz / Max 1.05 GHz, handles headless boot & local display if needed |
| **Discrete GPU** | ZOTAC GeForce 210 (512MB DDR2) | **Removed / Depopulated**: Physically removed to save ~20W idle power and eliminate unnecessary heat generation |
| **Motherboard** | ASUS H61M-K | Rev 2.02, Intel H61 Express Chipset, Micro-ATX, UEFI AMI BIOS, Anti-Surge Protection |
| **Memory (RAM)** | 10 GB DDR3-1600 Dual-Channel | Slot 1: 2GB Apacer DDR3-1600 CL11 (1.5V)<br>Slot 2: 8GB DDR3-1600 CL11<br>Total: 10,240 MB available for Docker containers and in-memory caches |
| **Primary Storage (HDD)** | 500GB Samsung Spinpoint F3 | Model: `HD502HJ`, 3.5" SATA 3Gb/s, 7200 RPM, 16MB Cache |
| **Storage Optimization** | Linux `hdparm` Idle Spin-down | Configured via `hdparm -S 120 -B 127 /dev/sdb` (spins down platters after 10 min idle, eliminating rotational noise) |
| **Power Supply Unit (PSU)** | ASUS P.S.I (Model: PS-2000W) | Iranian market commercial label; actual +12V rail capacity ~168W. Configured with low-noise fan mod |
| **CPU Cooling Assembly** | NIDEC Intel Stock Cooler | Model: `E97379-001`, 12V DC 0.28A, 4-Pin PWM, aluminum heatsink |
| **Cooler Acoustic Mod** | Refurbished / Serviced | Bearing cleaned & lubricated with light machine oil; Green GT-6 thermal paste applied; Q-Fan set to `Silent` (~800 RPM) |
| **Network Interface** | Realtek RTL8111F Gigabit Ethernet | 10/100/1000 Mbps RJ-45 LAN, plugged directly into AX3000T Gigabit switch |
| **Audio Subsystem** | Realtek ALC887 8-Channel HD Audio | Disabled in BIOS for headless server power saving |
| **Optical Drive** | Sony Optiarc DVD-RW (DRU-870S) | Disconnected / depopulated to eliminate standby power drain |

---

## 2. Acoustic Zeroing & 24/7 Silent Server Engineering

To allow 24/7 operation inside a bedroom/residential environment without audible noise, the following hardware and firmware optimizations are applied:

1. **Discrete GPU Elimination:**
   - The passive/small-fan ZOTAC GT210 was removed. Running on the integrated Intel HD graphics via CPU lowers total system idle consumption from ~52W to ~32W.
2. **ASUS Q-Fan Thermal Curve Tuning:**
   - In ASUS UEFI (`Monitor` -> `CPU Q-Fan Configuration`), CPU Fan Profile is set to **`Silent`**.
   - Minimum fan duty cycle: 20% (~800 RPM in idle state, below ambient noise floor).
3. **NIDEC Fan Shaft Servicing:**
   - Shaft bearing lubricated with high-grade light mechanical oil to eliminate dry-bushing squeal.
4. **Mechanical HDD Spindown & Acoustic Dampening:**
   - The Samsung 7200 RPM drive is decoupled with rubber dampening washers on the drive bay to kill chassis resonance.
   - Spindown timeout is enforced via `/etc/hdparm.conf`:
     ```ini
     /dev/disk/by-id/ata-SAMSUNG_HD502HJ_* {
         spindown_time = 120
         apm = 127
     }
     ```
5. **Headless OS Environment:**
   - Debian 12 Minimal or Ubuntu Server (no GUI/X11, text console only) to ensure CPU utilization remains < 1% during background operation.

---

## 3. Network Architecture & Home Ecosystem Integration

```
                 Internet (5G Cellular WAN / Future FTTH)
                                    │
                         ┌──────────▼──────────┐
                         │   ZLT X28 (Modem)   │ 192.168.70.1
                         └──────────┬──────────┘
                                    │
                         ┌──────────▼──────────┐
                         │ Xiaomi AX3000T (AP) │ 192.168.1.1 (Gateway)
                         └─────┬────────────┬──┘
                               │ Gigabit    │ Wi-Fi 6
                               │            │
       ┌───────────────────────▼────────┐  ┌▼────────────────────────────┐
       │ Legacy HomeLab PC              │  │ Samsung Q70C QLED TV        │
       │ (Pentium G2030 / 10GB DDR3)    │  │ (Tizen OS 9.0)              │
       │ · IP: 192.168.1.110 (Static)   │  │ · IP: 192.168.1.105         │
       │ · Jellyfin 4K Local Media      │  │ · Client: Jellyfin AVPlay   │
       │ · qBittorrent-nox Downloader   │  │ · Client: Moonlight / Chiaki│
       │ · Docker / Home Assistant OS   │  │ · Local IPTV via Router     │
       │ · Sing-Box High-Speed Gateway  │  └─────────────────────────────┘
       └────────────────────────────────┘
```

### 3.1. Roles Assigned to Legacy HomeLab PC
1. **Media Hub for Samsung Q70C:** Hosts the Jellyfin Server for movies/series, directly streamed to the TV's sideloaded `AprZAARz4r.Jellyfin` AVPlay client with zero network buffering.
2. **Off-Peak Automated Downloader:** Runs `qBittorrent-nox` with Web UI to download scheduled files during free/discounted data windows (e.g. Samantel Friday off-peak rate).
3. **Proxy Crypto Offload:** Can run an independent Sing-Box core with multi-gigabit throughput to relieve AX3000T's limited 256MB RAM.
4. **Local IoT & Home Assistant:** Runs Home Assistant containers for local automation of Zigbee/Matter/Smart home appliances.
