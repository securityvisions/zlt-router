# Video Transcript & In-Depth Review Analysis: TCI Tanoma FTTH

## Source: Koorosh Chaichi 1-Year Operational Field Review (`FFkclPM4R1I`)
- **Published**: Late 2024 / Recent (analyzing full year 2024-2025).
- **Duration**: 15:51 minutes.
- **Transcript File**: `.scratch/ftth-ponak-deployment/koorosh_transcript.txt` (321 lines extracted).

---

## 1. Speeds & Throughput Reality
- **Advertised vs Real**: Advertised as "up to 1000 Mbps", but real speed is capped/profiled at **360 to 400 Mbps** (~40 to 45 MB/s download).
- **Consistency**: The 360-400 Mbps is stable and sustained without throttling during normal daytime/night hours.
- **Upload**: Symmetrical speeds are not provided; upload is sufficient for concurrent 4K streaming, FaceTime video/audio, and Google Meet without lag.

## 2. Gaming, Latency, and DNS
- **Gaming Experience**: Tested with Destiny 2; very low latency and smooth without frame/packet drops.
- **DNS Requirements**:
  - PlayStation works fine without special DNS.
  - Xbox and certain PC platforms require custom DNS due to sanctions/geoblocking.
  - Recommended setup: Primary DNS Shelter / Secondary OpenDNS (`208.67.222.222`).

## 3. Censorship, Filtering & VPN Protocols
- **Mass Outage Vulnerability**: When nationwide Internet blackouts happen (e.g. June, January, March), TCI is among the first to get throttled/blocked.
- **Protocol Matrix on TCI Tanoma**:
  - **WireGuard**: 100% BLOCKED. Cannot connect at all.
  - **Commercial VPN IPs**: Blocked at routing level (NordVPN connects but routes 0 bytes).
  - **WebSocket / TLS Tunnel**: High jitter, intermittent disconnects.
  - **UDP Protocols (Hysteria 2 / Custom VPS UDP)**: Works smoothly ("مثل بنز کار میکنه") on standard ports (443, 80, 53).
  - **Dynamic Public IPv4 Advantage**: Unlike cellular networks, the lack of CGNAT prevents random disconnects.

## 4. Tariff & Commercial Tanoma Hack
- **Commercial Tanoma Option**:
  - The reviewer was offered "Commercial Tanoma" (تانوما تجاری) simply by asking/contract options.
  - Massive data packages:
    - 1600 GB (1.6 TB) for ~1.45M Tomans + tax (~1.6M Tomans/mo).
    - 2310 GB for ~1.95M Tomans/mo.
    - 4300 GB for ~3.7M Tomans/mo.
- **Comparison to HighWeb / Shatel**:
  - HighWeb cost 440,000 Tomans for only 100 GB (spending >2.5M for 500 GB).
  - TCI per-GB rate is drastically cheaper (less than 1,000 Tomans per GB on large plans).
  - Shatel online coverage map is deceptive ("coverage commitment" vs actual fiber trenching; users wait 7 months for refunds).

## 5. Total Installation Cost Breakdown
- Reviewer spent ~5,000,000 Tomans total:
  - ONT/Modem: 3,200,000 Tomans (purchased own unit).
  - Drop cabling & accessories: ~1,500,000 - 1,800,000 Tomans.
- Rating: **7 / 10** (Points lost to national shutdown susceptibility and 360M cap instead of 1000M; points won for low GB cost, high stability, and smooth custom UDP/Reality VPN performance).
