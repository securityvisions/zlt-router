# Lenovo Legion 5 (16IAX10 — Model 83NX) — Complete Workstation Specification & Operations Manual

This document is the canonical reference for the primary developer/gaming workstation on the home network: the user's Lenovo Legion 5 laptop running Omarchy Linux (Hyprland Wayland) and dual-boot Windows 11.

---

## 1. System Profile & Hardware Specifications

| Component | Specification | Technical Details & State |
|---|---|---|
| **Commercial Model** | Lenovo Legion 5 16IAX10 | Model Code: `83NX` (2025/2026 Gen) |
| **Processor (CPU)** | Intel Core Ultra 9 275HX | Arrow Lake-S architecture, 24 Cores (8 Performance + 16 Efficient), 24 Threads, up to 5.4 GHz, 36MB Intel Smart Cache |
| **CPU Governor & Power** | `intel_pstate` | `powersave` with `balance_performance` EPP profile, thermald enabled |
| **System Memory (RAM)** | 32 GB DDR5-5600 | Dual-channel high-speed DDR5 |
| **Primary Storage (NVMe)**| 1 TB Samsung PCIe 4.0 NVMe SSD | Ultra-low latency system & workspace drive |
| **Discrete GPU (dGPU)** | NVIDIA GeForce RTX 5060 Laptop GPU | 8 GB GDDR6 VRAM, Blackwell architecture (GB206M), `nvidia-open-dkms 610.57`, CUDA 13.1 |
| **dGPU Power Management** | Runtime D3 (RTD3) | Dynamic D3cold PCIe bus suspension when idle (zero watt drain until invoked by `prime-run`) |
| **Integrated GPU (iGPU)** | Intel Graphics (Arrow Lake) | `intel-media-driver` (`iHD`), full VA-API hardware decode/encode (AV1, HEVC 10-bit, VP9, H.264) |
| **Display Panel** | 16" WQXGA (2560x1600, 16:10) | 240Hz refresh rate, 100% sRGB, Adaptive Sync / VRR, 500 nits brightness |
| **Primary Operating System**| Omarchy Linux | Arch-based Linux (Kernel 7.2.5-3-omarchy), Hyprland Wayland compositor |
| **Secondary OS** | Windows 11 Pro | WSL2 Linux environment (Kernel 6.18) |
| **Networking (Wi-Fi)** | Wi-Fi 6E / Wi-Fi 7 (802.11ax/be) | Connected to `XI-5G` (5GHz HE80, AX3000T) with static DHCP binding |
| **Networking (Ethernet)** | Realtek 2.5GbE / Gigabit RJ-45 | Direct cable triage capable (metric 9999 hotspot safety policy) |
| **Battery & Charging** | 80Wh Li-Polymer | Lenovo Conservation Mode active (hard-capped at 80% charge threshold via `lenovolegionlinux`) |

---

## 2. Linux Ecosystem & Display Stack (Omarchy / Hyprland)

1. **Wayland & VRR Architecture:**
   - Display configured at **2560x1600 @ 240Hz**.
   - Hyprland configured with `misc:vrr = 2` (variable refresh rate dynamically applied in fullscreen gaming) and `general:allow_tearing = true` for zero-latency competitive input.
2. **Hardware Video Acceleration:**
   - `LIBVA_DRIVER_NAME=iHD` exported across Hyprland session and `/etc/environment.d/`. All browser video playback (YouTube 4K60, Twitch) and media players utilize the Intel Arrow Lake iGPU with near-zero CPU load.
3. **Hybrid Graphics (PRIME Offload):**
   - General desktop, terminals, and editors run on the power-efficient Intel iGPU.
   - High-performance applications, games, and CUDA deep learning scripts are launched via:
     ```bash
     gamemoderun prime-run %command%
     ```
   - RTD3 automatically transitions the RTX 5060 into D3cold state when games exit, saving battery and eliminating fan noise.
4. **Thermal & Performance Control:**
   - Kernel module `lenovolegionlinux` manages custom fan curves.
   - Integrated with `power-profiles-daemon` for switching between Quiet, Balanced, and Performance modes.

---

## 3. Network Role & Interaction with Home Ecosystem

```
             ┌────────────────────────────────────────────────────────┐
             │       Lenovo Legion 5 (16IAX10 / Ultra 9 275HX)        │
             │   · Omarchy Linux (Hyprland) / Windows 11 Dual Boot    │
             │   · RTX 5060 Blackwell / 32GB DDR5 / 240Hz WQXGA       │
             └───────────┬────────────────────────────────┬───────────┘
                         │ Wi-Fi 6 (XI-5G)                │ Ethernet (Wired)
                         ▼                                ▼
             ┌────────────────────────────────────────────────────────┐
             │         Xiaomi AX3000T (192.168.1.1 Gateway)           │
             └───────────┬────────────────────────────────┬───────────┘
                         │                                │
        ┌────────────────▼───────────────┐  ┌─────────────▼───────────────┐
        │ Legacy HomeLab PC (192.168.1.110)│  │ Samsung Q70C TV (192.168.1.105)│
        │ · Docker / Jellyfin Media      │  │ · Moonlight 4K120 Stream    │
        │ · Off-Peak Download Station    │  │ · Chiaki Remote Play        │
        └────────────────────────────────┘  └─────────────────────────────┘
```

1. **Moonlight 4K120 Game Streaming:**
   - The Legion 5's RTX 5060 and Ultra 9 CPU run Sunshine GameStream server.
   - Streams 4K 60fps/120fps PC games with HDR directly to the Samsung Q70C QLED TV's sideloaded Moonlight app (`MoonLightS.MoonlightWasm`) across the AX3000T local gigabit Wi-Fi 6 mesh.
2. **Control Plane & SSH Management:**
   - Primary workstation from which AX3000T (`192.168.1.1`), X28 (`192.168.70.1`), Remote VPS 1 (`85.121.124.158`), Remote VPS 2 (`5.175.234.113`), and the Legacy HomeLab PC (`192.168.1.110`) are managed via SSH keys (`~/.ssh/id_ed25519_agent`).
3. **Triage & Failsafe Handling:**
   - Adheres to the Laptop Hotspot Triage Protocol (Section 3 of the Complete Reference), preventing Windows/Linux default gateway metric collisions during cellular tethering troubleshooting.
