# FTTH Deployment Strategy (Ponak Faraz Park) & Mini-PC Utility Analysis

**Date:** September 14, 2026  
**Target Location:** Tehran, District 5, Ponak (پونک), In front of Faraz Park (پارک فراز)  
**Building Profile:** Newly built 12-unit residential complex (ساختمان نوساز ۱۲ واحدی)  
**Author:** Network & Systems Operations Agent

---

## 1. Executive Summary & Core Conclusion

1. **Fiber Optic (FTTH) is the Ultimate Speed Game-Changer:**
   Cellular 5G (ZLT X28) averages 50–90 Mbps with 35–80ms jitter. FTTH delivers **300 to 1,000 Mbps symmetric/asymmetric bandwidth with <5ms domestic ping**, complete immunity to cell tower congestion, and vastly lower per-Gigabyte data costs.
2. **The 12-Unit Newly Built Advantage:**
   Telecommunication operators in Iran rarely pull fiber from the street for a single apartment. However, a **12-unit residential building hits the commercial threshold** where both **Shatel Fiber** and **TCI (Mokhaberat Tanoma)** will trench, install a FAT (Fiber Access Terminal), and pull riser cabling into the building **free of charge or heavily subsidized**.
3. **Second ZLT X28 vs. Mini-PC vs. FTTH Recommendation:**
   - **Do NOT buy a second ZLT X28 right now:** Spending 12–16 million Tomans on another 5G modem (plus ongoing double SIM card fees) gives at most ~150 Mbps and still suffers from cellular radio jitter.
   - **Initiate FTTH application immediately (Zero Upfront Cost):** Contact Shatel Complex Solutions (`021-91000911`) and TCI Shahid Nazari Center. The survey and feasibility assessment are 100% free.
   - **Invest in a Refurbished Mini-PC (~15–20M Toman):** Once FTTH or solid uplink is secured, a Mini-PC transforms your network into an enterprise-grade private cloud, multi-gigabit VPN/proxy router, automated 4K media server, and Home Assistant hub.

---

## 2. FTTH Coverage & Operator Analysis for Ponak (Faraz Park)

### 2.1. Telecom Center Jurisdiction
- **Primary Serving Center:** **مرکز مخابرات شهید نظری (Shahid Nazari)**
  - Address: Tehran, District 5, Ponak, Sardar Jangal Ave, before Mirza Babaei 4-way intersection (خیابان سردار جنگل، نرسیده به چهارراه میرزابابایی).
  - Phone Prefix Ranges: `4440` through `4449`, `4460`, `4480`.
  - Jurisdiction: Ponak, Faraz Park, Kamal-e-Esmaeel, Mirza Babaei, Adl, Hemila.
- **Secondary Adjacent Center:** **مرکز مخابرات پیام نور (Payam-e-Nour)** (Ashrafi Esfahani / Abazar).

### 2.2. Operator Field Map
- **National Portal Outage Note:** The official CRA national fiber portal (`iranfttx.ir`) is currently inaccessible due to an expired SSL certificate and origin server timeouts. Field verification confirms coverage must be pursued directly through operators.
- **TCI Tanoma (تانوما مخابرات):**
  - Owns the primary underground duct infrastructure on Sardar Jangal, Mirza Babaei, and main avenues of Ponak.
  - Inquiries: Building manager submits inquiry at امور مشترکین مرکز مخابرات شهید نظری (واحد فیبر نوری).
- **Shatel Fiber (شاتل فایبر):**
  - Actively deploying FTTH in Tehran District 5 under CRA UNSP license.
  - Has dedicated field teams and a specialized division for residential complexes (`021-91000911`).

---

## 3. Step-by-Step Acquisition Roadmap for 12-Unit Building

```
[Step 1: Resident Agreement] ──► [Step 2: Dual Operator Inquiries] ──► [Step 3: Free Feasibility Survey]
                                         │
        ┌────────────────────────────────┴────────────────────────────────┐
        ▼                                                                 ▼
[TCI Shahid Nazari Commercial Office]                            [Shatel Complex Desk 021-91000911]
        │                                                                 │
        └────────────────────────────────┬────────────────────────────────┘
                                         ▼
                       [Step 4: FAT Box & Street Trenching]
                                         ▼
                       [Step 5: Vertical Riser Microducts]
                                         ▼
                   [Step 6: Unit ATB Sockets & GPON ONT Modems]
                                         ▼
            [Step 7: Direct Gigabit Uplink to Xiaomi AX3000T Router]
```

### 3.1. Phase 1: Collective Intent (1–2 Days)
- Draft a simple group request letter on behalf of the building board/manager:
  > «ریاست محترم مرکز مخابرات شهید نظری / مدیر محترم فروش مجتمع‌های شرکت شاتل  
  > احتراما اینجانب مدیر ساختمان نوساز ۱۲ واحدی واقع در پونک، [آدرس دقیق، پلاک، کد پستی ۱۰ رقمی] به همراه اهالی و ساکنین مجتمع، تقاضای امکان‌سنجی و اجرای فیبر نوری (FTTH/تانوما) جهت تجهیز ساختمان به اینترنت پرسرعت فیبر را داریم.»
- Get signatures from 4 to 8 units. (Having 8+ applicants guarantees priority scheduling).

### 3.2. Phase 2: Parallel Operator Submission
1. **Shatel Track (Fastest Commercial Response):**
   - Call `021-91000911` (واحد ویژه مجتمع‌های مسکونی شاتل).
   - Or register on: `https://www.shatel.ir/internet-services/towers-special-services/`
   - Shatel policy for 10+ unit buildings:
     - **Equipment & FAT box:** Provided on free loan (امانی).
     - **Installation fee:** 0 Toman.
     - **Cabling labor:** Free of charge (شاتل اجرت کابل‌کشی را متقبل می‌شود).
   - Shatel dispatches an engineer for an on-site survey within 48 to 72 hours.
2. **TCI Track (Mokhaberat Tanoma):**
   - Building manager visits امور مشترکین مرکز مخابرات شهید نظری with the letter and postal code.
   - The head of fiber planning checks the GIS database for the nearest fiber manhole (حوضچه مخابرات). If within ~100–200 meters, a work order is generated for the civil contractor.

### 3.3. Phase 3: Physical Architecture & Cabling
1. **FAT Box (Fiber Access Terminal):** An outdoor/indoor IP65 16-port distribution box installed in the parking or telecom riser room on the ground floor/basement.
2. **Riser Cabling:** Because the building is newly built, vertical electrical/telecom riser shafts already exist. Operators pull flexible 1-core or 2-core G.657.A2 drop cables up the riser pipe into each apartment.
3. **ATB (Access Terminal Box):** A compact white wall socket inside your flat near your existing Xiaomi AX3000T router.
4. **ONT Modem:** Connects via SC-UPC patch cord. Configure the ONT in **Bridge Mode**.
5. **AX3000T Integration:** Plug an Ethernet cable from the ONT's LAN1 port into Port 1 (`wan`) of the Xiaomi AX3000T. The AX3000T handles PPPoE authentication, hardware NAT, Wi-Fi 6 distribution, and transparent proxying across the whole household at gigabit speeds!

### 3.4. Cost Estimation

| Component | Cost (Single Resident) | Cost (12-Unit Building Package) | Who Pays |
|---|---|---|---|
| **Street Trenching & Subduct** | 15,000,000 – 35,000,000 T | **0 Toman** (Covered by Operator) | Operator subsidy |
| **16-Port FAT Box & Splitter** | 3,000,000 – 6,000,000 T | **0 Toman** (Supplied on loan) | Operator |
| **Riser Cabling Labor** | 2,000,000 – 4,000,000 T | **0 Toman** (Promotional incentive) | Operator |
| **Metered Drop Cable (per unit)** | ~30,000 T / meter | ~500,000 – 1,200,000 T / unit | Each requesting unit |
| **GPON ONT Modem** | 2,000,000 – 3,500,000 T | Bundled free or ~2.5M T in packages | Unit owner |
| **High-Speed Package (e.g. 2400GB)**| ~15,000,000 – 20,000,000 T | Promotional bundles (3–6 months) | Unit owner |

---

## 4. Comprehensive Refurbished Mini-PC Utility Breakdown

A refurbished enterprise Mini-PC (e.g., **HP EliteDesk 800 G3/G4 Mini**, **Lenovo ThinkCentre M710q/M910q Tiny**, or **Dell OptiPlex 7050 Micro**) equipped with an Intel Core i5 (6th–8th gen), 16GB–32GB DDR4 RAM, and 256GB–512GB NVMe SSD costs **15,000,000 to 22,000,000 Tomans** and consumes only **15 to 35 Watts** of electricity.

### 4.1. Comparison: Xiaomi AX3000T vs. Mini-PC

| Dimension | Xiaomi AX3000T Router | Refurbished Mini-PC |
|---|---|---|
| **CPU Architecture** | Dual-core ARM Cortex-A53 @ 1.3GHz | Quad/Hexa-core x86_64 Intel Core i5 @ 3.2–4.1GHz |
| **RAM** | 256 MB DDR3 (92 MB available) | 16 GB to 32 GB DDR4 (Expandable) |
| **Storage** | 60 MB Flash Overlay (26 MB free) | 256 GB – 2 TB NVMe SSD + SATA 2.5" Bay |
| **Crypto Acceleration** | Basic ARM CE / EIP-197 | Hardware **AES-NI** (multi-gigabit wire speed) |
| **Video Transcoding** | None | **Intel QuickSync Video** (Hardware 4K HEVC/H.264) |
| **Containerization / VMs**| None (Storage & memory prohibitive) | Full **Docker** & **Proxmox VE** hypervisor |
| **Primary Role** | Fast Layer 2/3 Wi-Fi 6 Switch & AP | Enterprise Home Server, Media Hub & Proxy Engine |

---

### 4.2. Top 7 Capabilities of a Home Mini-PC

```
┌─────────────────────────────────────────────────────────────────────────────────┐
│                      PROXMOX VE / UBUNTU SERVER ON MINI-PC                      │
├───────────────────┬───────────────────┬───────────────────┬─────────────────────┤
│  Core Gateway     │  Media & Storage  │  Smart Home & IoT │  Local AI & Dev     │
│  · Multi-Gbps     │  · Jellyfin/Plex  │  · Home Assistant │  · Ollama (Qwen 7B) │
│    Sing-Box       │    (4K QuickSync) │    (Zigbee/Matter)│  · Whisper Voice-AI │
│  · AdGuard Home   │  · Automated *arr │  · Mosquitto MQTT │  · Private GitLab   │
│  · Headscale/VPN  │    (qBittorrent)  │    Broker         │    Runner           │
│  · HAProxy/Nginx  │  · Immich Photos  │  · Vaultwarden    │  · Scraper Bots     │
└───────────────────┴───────────────────┴───────────────────┴─────────────────────┘
```

#### 1. Multi-Gigabit Zero-Bottleneck Proxy Gateway
- **Problem on Routers:** When passing 200–500 Mbps of encrypted Reality/Hysteria2 traffic on the router, CPU hits 100%, causing latency spikes for family members.
- **On Mini-PC:** An Intel Core i5 with AES-NI instructions handles **over 3,000 Mbps of encrypted VLESS/Reality or Hysteria2** while using less than 10% CPU. You can run Sing-Box or Mihomo as a VM/Container, with multi-gigabyte in-memory caching and zero dropped packets.

#### 2. Personal Netflix: 4K Home Streaming (Jellyfin / Plex)
- Install **Jellyfin** (free, open source) with hardware acceleration enabled via Intel QuickSync.
- Plug in an external or internal 2TB–4TB drive holding movies and series.
- You can stream 4K HDR and 1080p content to smart TVs, iPhones, Androids, and laptops inside the house with instant playback, subtitle syncing, and zero buffering.

#### 3. 24/7 Automated Download Station (*arr Stack + qBittorrent)
- Pair `qBittorrent-nox` with the automation suite: `Radarr` (movies), `Sonarr` (series), `Prowlarr` (torrent indexers), and `Bazarr` (subtitles).
- Add a movie from your phone via a clean web UI; the Mini-PC automatically finds the torrent, schedules downloads during off-peak/free night windows, extracts subtitles, organizes the folder structure, and notifies your TV.

#### 4. Google Photos & iCloud Replacement (Immich)
- **Immich** is a self-hosted photo/video backup app matching Google Photos' UI.
- Backs up your phone's camera roll automatically over Wi-Fi when you walk in the door.
- Runs local machine learning (face detection, object search, geolocation tagging) on the Mini-PC CPU, completely private and without monthly subscription fees.

#### 5. Self-Hosted Password Vault (Vaultwarden)
- A lightweight Bitwarden server written in Rust that consumes less than 30MB of RAM.
- Stores passwords, 2FA tokens, and sensitive notes on your local hardware, synced securely across your phone and browser extensions.

#### 6. Offline Smart Home Controller (Home Assistant OS)
- Runs Home Assistant in a dedicated Proxmox VM.
- Controls smart switches, relays, lighting, and cameras completely locally. Even if the internet or cellular towers go down entirely, your smart home lights, alarms, and automations continue working.

#### 7. Local AI & Voice Processing (Ollama & Whisper)
- Run quantized 7B parameter models (e.g. Qwen 2.5 7B, Mistral 7B) on CPU using AVX2 instructions at ~4–8 tokens/second for local scripting, document analysis, and private LLM chat.
- Run OpenAI Whisper locally for speech-to-text transcription.

---

## 5. Strategic Investment Matrix: What to Do First?

| Investment Option | Capital Outlay | Bandwidth Impact | Latency Impact | Operational Value |
|---|---|---|---|---|
| **Option A: Second ZLT X28 Modem** | 12,000,000 – 16,000,000 T | +50 to +70 Mbps | Minor (still cellular 40ms+) | Low (duplicate hardware, ongoing monthly SIM fees) |
| **Option B: FTTH Collective Deployment** | **0 Toman to start** (4M–15M T / unit final) | **+300 to +1000 Mbps** | **Massive (<5ms ping)** | **Highest Possible (Transforms entire home foundation)** |
| **Option C: Refurbished Mini-PC** | 15,000,000 – 22,000,000 T | 0 Mbps directly (accelerates processing) | Zero jitter on proxy crypto | **High (Unlocks private cloud, media server, home lab)** |

---

## 6. Concrete Recommended Action Plan

1. **Step 1 (Today — Free):**
   Do not spend money on a second cellular modem. Contact **Shatel Residential Complexes Desk** at **`021-91000911`** and request a free technical survey for your 12-unit building in Ponak (Faraz Park).
2. **Step 2 (This Week — Free):**
   Have the building manager take a brief application letter to **مرکز مخابرات شهید نظری** (خیابان سردار جنگل) to inquire about the nearest Tanoma fiber manhole.
3. **Step 3 (Budget Allocation):**
   - Use your available budget for the **FTTH connection and ONT package** when the operator approves the building. This gives your household a true 300–1000 Mbps gigabit pipeline.
   - Once FTTH is established (or while waiting for trenching), invest your budget in an **HP EliteDesk 800 G3/G4 Mini** (or Lenovo Tiny) with Intel Core i5 and 16GB RAM. Connect it directly via gigabit Ethernet to the AX3000T to serve as the powerhouse media server, private cloud, and multi-gigabit proxy core.
