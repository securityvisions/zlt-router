# Redmi Note 9S (Curtana / Miatoll) — Blackout Survival & MITM Edge Device Reference

This document is the canonical reference for the connected rooted mobile appliance on the home network: the user's Xiaomi Redmi Note 9S (`curtana`) configured as an offline survival node, emergency DNS tunnel client, and MITM domain fronting terminal.

---

## 1. System Profile & Hardware Specifications

| Component | Specification | Technical Details & State |
|---|---|---|
| **Commercial Model** | Xiaomi Redmi Note 9S | Codename: `curtana` / Family: `miatoll` |
| **Processor (SoC)** | Qualcomm Snapdragon 720G (SM7125) | 8 Cores (2× Kryo 465 Gold @ 2.3 GHz + 6× Kryo 465 Silver @ 1.8 GHz, 8nm) |
| **GPU** | Qualcomm Adreno 618 | Vulkan 1.1, OpenGL ES 3.2 |
| **Architecture** | `arm64-v8a` (64-bit ARM) | Native execution target for Linux Go binaries |
| **Operating System** | Android 16 (Custom ROM) | Linux Kernel `4.14.348`, SELinux Enforcing |
| **Root Solution** | Magisk 28.x | Root context: `uid=0(root) gid=0(root) context=u:r:magisk:s0` |
| **USB Debugging** | Authorized ADB Interface | Platform-tools access via workstation (`/home/parsavisions/Android/Sdk/platform-tools/adb`) |
| **Storage Capacity** | 64GB/128GB UFS 2.1 | Dedicated emergency bundle mounted at `/sdcard/Blackout-Prep/` |
| **Battery Capacity** | 5020 mAh Li-Po | High-endurance emergency power source for local hotspot & radio duties |

---

## 2. Certificate Architecture & MITM Domain Fronting

In an advanced censorship environment, DPI engines block public Server Name Indication (SNI) and inspect TLS handshakes. MITM Domain Fronting overcomes this by rewriting SNI headers and terminating TLS locally using a custom Root Certificate Authority.

### 2.1. Magisk `trustusercerts` Module
- **Module Path:** `/data/adb/modules/trustusercerts`
- **Mechanism:** Intercepts system boot mounting (`/system/etc/security/cacerts/`). At boot time, Magisk overlays `/system/etc/security/cacerts` with a writable tmpfs/overlayfs and copies user-installed certificates into the system root trust store.
- **Root CA Hash:** `2fd38180` (Old OpenSSL subject hash format required by Android).
- **Target File:** `/data/adb/modules/trustusercerts/system/etc/security/cacerts/2fd38180.0`
- **Subject / Validity:** `CN=Blackout-MITM-Root-CA`, 2048-bit RSA, valid for 10 years (until 2036).
- **Impact:** All Android applications, Chrome/Chromium web views, and background system services trust the custom CA unconditionally without displaying the standard Android "Network may be monitored" warning dialog.

---

## 3. Offline Survival Bundle (`/sdcard/Blackout-Prep/`)

The device holds an autonomous survival environment completely decoupled from cloud connectivity:

```text
/sdcard/Blackout-Prep/
├── iran-blackout-checklist.md    # Master emergency manual ("۲ روز مانده به جنگ")
├── Free-Configs.txt              # Scraped and verified fallback proxy configs
├── Serverless-for-Iran.json      # Xray-core serverless subscription
├── V2RayAggregator.txt           # Multi-protocol configuration pool
├── dnstt-client-arm64            # Statically compiled DNS tunnel client (Go 1.24)
├── start_dnstt_phone.sh          # Automated root launcher script
├── MITM-Certs/                   # Generated private keys and PEM certificates
└── APKs/                         # Offline application installers (APK)
    ├── Briar.apk                 # P2P mesh messenger (Bluetooth & local Wi-Fi, no internet)
    ├── Hiddify.apk               # Universal proxy client (Sing-Box core)
    ├── Kiwix.apk                 # Offline Wikipedia and medical ZIM archives reader
    ├── NekoBox.apk               # Multi-protocol proxy client (Sing-Box/Xray/Hysteria2)
    ├── OrganicMaps.apk           # Complete offline GPS navigation & OpenStreetMap
    ├── PattNG.apk                # Patterniha specialized serverless client
    └── Psiphon.apk               # High-concurrency blackout bypass engine
```

---

## 4. Emergency DNS Tunneling Operations (`dnstt`)

When cellular data carriers (MCI, Irancell, Rightel) disable international routing and drop all foreign TCP/UDP traffic:

1. **Launcher Script:** `/sdcard/Blackout-Prep/start_dnstt_phone.sh`
   - Copies binary to `/data/local/tmp/dnstt/` to bypass Android SDCard `noexec` mount restrictions.
   - Binds a local SOCKS5 proxy to `127.0.0.1:5300`.
   - Routes Base32 chunks over UDP port 53 to authoritative root `t.dmbz.ir`.
2. **Execution via Termux or ADB Root:**
   ```bash
   su -c "sh /sdcard/Blackout-Prep/start_dnstt_phone.sh 8.8.8.8:53"
   ```
3. **Application Routing:**
   - Configure **NekoBox** or **PattNG** with a local SOCKS5 inbound:
     - Server: `127.0.0.1`
     - Port: `5300`
   - Configure **Telegram** (Settings $\to$ Data and Storage $\to$ Proxy Settings $\to$ Add Proxy $\to$ SOCKS5):
     - Server: `127.0.0.1`
     - Port: `5300`
   - All text messages, alert channels, and emergency notifications will route over the surviving DNS infrastructure.
