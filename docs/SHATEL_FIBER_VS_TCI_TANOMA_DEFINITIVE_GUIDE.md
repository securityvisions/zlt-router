# Shatel Fiber vs. TCI Tanoma: Definitive Head-to-Head Comparative Guide

**Context:** Newly built 12-unit residential complex in Ponak (Faraz Park), Tehran District 5  
**Serving Telecom Center:** مرکز مخابرات شهید نظری (خیابان سردار جنگل)  
**Date:** September 14, 2026  
**Document Classification:** Primary Technical & Commercial Evaluation

---

## 1. Head-to-Head Scorecard Matrix

| Evaluation Vector | Shatel Fiber (شاتل فایبر) | TCI Tanoma (تانوما مخابرات) | Winner | Strategic Analysis |
|---|---|---|---|---|
| **Base Monthly Cost** | ~300,000 – 800,000 Toman/mo | **190,000 – 675,000 Toman/mo** | **TCI Tanoma** | TCI offers lower entry thresholds for light users. |
| **High-Volume Festivals** | **2,400 GB / 6 mo (~20M T with ONT)** | 6,000 GB / 12 mo (~7.5M T + ONT) | **Tie** | Shatel bundles hardware and service; TCI offers raw volume. |
| **Hardware / ONT Freedom** | Vendor-locked ONT bundled in festival | **Bring Your Own ONT (BYO ONT allowed)** | **TCI Tanoma** | TCI allows using cheap bridge ONTs (Huawei HG8010H). |
| **Public IP Address** | **CGNAT (100.64.0.0/10)** by default | **Dynamic Public IPv4 by default** | **TCI Tanoma** | Critical for direct incoming ports, DDNS, and server hosting. |
| **DPI & Filtering Aggression** | High edge DPI; aggressive on raw UDP | Standard TIC filtering; more lenient on UDP | **TCI Tanoma** | Hysteria2 and WireGuard face less throttling on TCI. |
| **VLESS + Reality Support** | **Excellent (Wire Speed, 300M+)** | **Excellent (Wire Speed, 300M+)** | **Tie** | Both pass TLS 443 handshakes without issue. |
| **Gaming Ping (Europe/Frankfurt)**| **68 – 85 ms (Gaming Profile / FastPath)** | 85 – 115 ms (Standard TIC route) | **Shatel Fiber** | Shatel's FastPath profile gives noticeable competitive edge. |
| **Peak-Hour Packet Loss** | **Minimal (<0.5% jitter)** | Moderate during 20:00–23:00 national spikes | **Shatel Fiber** | Shatel's private AS31549 core manages queueing better. |
| **Complex Subsidies (12 Units)** | **Free FAT + Free Riser Labor (100%)** | Free/Subsidized FAT upon center approval | **Shatel Fiber** | Shatel has an aggressive corporate policy for 10+ unit buildings. |
| **Customer Service & SLA** | **24/7 Helpdesk (91000000), 12–24h fusion** | IVR 2020, bureaucratic 48–72h fiber repairs | **Shatel Fiber** | Private SLA vs government bureaucracy. |

---

## 2. Detailed Dimension Analysis

### 2.1. Tariffs, Hardware & Billing Flexibility

#### TCI Tanoma
- **Entry Plans:** Starts from **190,000 Toman/month** for 45 GB international (121.5 GB domestic) up to **675,000 Toman/month** for 500 GB international.
- **Billing Mode:** Postpaid directly on your telephone bill (**پس‌پرداخت روی قبض تلفن ثابت**).
- **Hardware Independence:** TCI allows customers to purchase an independent GPON ONT bridge modem from the open market (e.g. Huawei HG8010H for ~1,800,000 to 2,500,000 Toman). You plug this directly into your existing **Xiaomi AX3000T** router, which performs PPPoE dial-up and handles all household Wi-Fi 6 routing.

#### Shatel Fiber
- **Bundled Festivals:** Shatel sells all-in-one promotional packages:
  - **Extreme (۶ ماهه):** 2,400 GB international (400 GB/month) + ONT Modem + Installation = **20,015,200 Toman**.
  - **Premium (۳ ماهه):** 300 GB international + ONT Modem + Installation = **15,363,280 Toman**.
- **Installment Option:** Available through **SnappPay / Shatel credit** (پرداخت در ۴ قسط بدون کارمزد).
- **Extra Traffic:** Averages **~1,800 to 2,400 Toman per GB**, slightly higher than TCI.

---

### 2.2. Filtering, DPI & Censorship Mechanics

#### The CGNAT Dilemma (Crucial Technical Difference)
- **Shatel Fiber puts residential users behind Carrier-Grade NAT (CGNAT `100.64.0.0/10`):**
  - Your router does not receive a real public IP address.
  - If you run self-hosted services at home (e.g. WireGuard server, Nextcloud, Home Assistant remote access) without a reverse tunnel or Tailscale, it will fail unless you pay **~30,000 to 50,000 Toman/month for a Static Public IP**.
- **TCI Tanoma gives a Dynamic Public IPv4 by default:**
  - Every time your AX3000T router connects to PPPoE, it receives a real internet-routable IPv4 address (e.g. `2.18x.x.x` or `5.x.x.x`).
  - You can use dynamic DNS (DDNS) freely to connect directly into your home network from outside without paying for a static IP.

#### VPN & Proxy Protocol Performance
- **VLESS + Reality (TCP 443):** Operates at maximum wire speed (300–800 Mbps) on **both** Shatel and TCI. Reality's browser-mimicking TLS handshake is virtually immune to ISP-level blocking.
- **UDP Protocols (Hysteria2 / QUIC / WireGuard):**
  - **Shatel** applies strict UDP traffic shaping and port-throttling during evening peak hours. Hysteria2 requires Salamander obfuscation to avoid packet rate drops.
  - **TCI** has looser UDP throttling on fixed fiber, though it remains subject to national infrastructure-level shutdowns during acute security events.

---

### 2.3. Gaming, Latency & Route Quality

- **Shatel Fiber is the Gold Standard for Iranian Gamers:**
  - Shatel offers a **"Gaming Profile" (پروفایل گیمینگ)** switchable in the MyShatel dashboard.
  - When enabled, Shatel's BGP edge prioritizes low-latency routes through Turkey/Europe.
  - Ping to `8.8.8.8`: **65–75 ms**
  - Ping to European game servers (Frankfurt Valve/CS2, Riot EU): **68–85 ms**
  - Local domestic ping (Tehran IXP): **1–3 ms**
- **TCI Tanoma:**
  - Ping to `8.8.8.8`: **80–95 ms**
  - Ping to European game servers: **85–115 ms**
  - Subject to occasional packet loss (1–3%) during peak evening hours (20:00–23:00) when national gateway traffic spikes.

---

### 2.4. Physical Fiber Deployment & Complex Support (Ponak 12-Unit Building)

#### The 12-Unit Complex Advantage
Neither operator will excavate a street for an individual flat. However, your **12-unit building** qualifies for enterprise residential treatment:

- **Shatel's Complex Policy (`021-91000911`):**
  - For buildings with ≥10 units where at least 8 units sign up:
    1. 16-port FAT box and optical splitters are provided **100% free on loan (امانی)**.
    2. Zero installation fee for the building.
    3. Shatel covers the labor cost for pulling vertical riser cabling up to apartment doors.
- **TCI Tanoma Policy (مرکز مخابرات شهید نظری):**
  - Requires the building manager to submit a formal group request letter.
  - TCI's civil contractor surveys the nearest manhole (حوضچه مخابرات) on Sardar Jangal or Mirza Babaei.
  - Bureaucracy can take 3 to 8 weeks to issue the municipal excavation permit.

#### Support & Fiber Cut SLA
- Optical fiber is delicate glass. Road construction, street repaving, or electrician mistakes can sever a drop cable.
- **Shatel SLA:** Maintains dedicated emergency fusion teams in Western Tehran. Dispatch and fusion splicing repair time is **12 to 24 hours**.
- **TCI SLA:** Handled via outsourced municipal contractors through the `2020` hotline. Cable breaks occurring on a Thursday afternoon or Friday typically sit unresolved until the following work week (**48 to 72+ hours**).

---

## 3. The Definitive Recommendation for Your Setup

```
                     ┌─────────────────────────────────────────────────────────┐
                     │          WHAT MATTERS MOST TO YOU IN PONAK?             │
                     └────────────────────────────┬────────────────────────────┘
                                                  │
                 ┌────────────────────────────────┴────────────────────────────────┐
                 ▼                                                                 ▼
      [Priority: Gaming Ping, Support,                               [Priority: Cheaper Bulk Data,
       Fast Install, 4-Installment Plan]                             Public Dynamic IPv4, No CGNAT]
                 │                                                                 │
                 ▼                                                                 ▼
         SHATEL FIBER (FTTH)                                              TCI TANOMA (FTTH)
    · FastPath Gaming (68–85ms)                                      · Dynamic Public IPv4 (No CGNAT)
    · Dedicated Complex Desk (021-91000911)                          · Pay on Fixed Phone Bill
    · 12–24h Repair SLA                                              · Cheap extra traffic (~1,500 T/GB)
    · 4-month SnappPay installment                                   · BYO ONT Modem allowed
```

### The Recommended Hybrid Strategy:
1. **Apply for BOTH immediately (Zero Risk / Zero Upfront Cost):**
   - Call **Shatel Complex Desk (`021-91000911`)** today. They will send an engineer for an on-site building survey within 48 hours for free.
   - Have the building manager submit a group letter at **مرکز مخابرات شهید نظری** (خیابان سردار جنگل).
2. **First to Trench Wins:**
   - Whichever operator approves street conduit access and arrives to mount the 16-port FAT box in your parking/riser first gets the contract.
3. **If Both are Available:**
   - **Choose Shatel Fiber** if low gaming latency, responsive 24/7 human support, and 4-installment payment are your priorities.
   - **Choose TCI Tanoma** if having a clean Public Dynamic IPv4 (no CGNAT for hosting) and paying cheap rates on your phone bill are your priorities.
