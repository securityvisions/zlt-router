# 03 - Refurbished Mini-PC Utility & HomeLab Matrix

**Type:** `research`  
**Status:** resolved

## Resolution

Delivered a granular capability analysis of an enterprise refurbished Mini-PC (Intel Core i5, 16-32GB RAM, NVMe SSD, ~15-35W idle):
1. **Compute vs Router Bottleneck:**
   - AX3000T: Embedded networking device (256MB RAM, 2x A53); cannot host storage, containers, or heavy services.
   - Mini-PC: x86_64 virtualization platform (Proxmox VE / Ubuntu Server) with hardware AES-NI and Intel QuickSync video decoding.
2. **Top Practical Use Cases:**
   - **Multi-Gigabit Proxy Powerhouse:** Runs sing-box/mihomo with AES-NI crypto offload, capable of 2-3 Gbps throughput with zero CPU strain.
   - **Plex/Jellyfin Media Server:** 4K real-time hardware transcoding to Smart TVs and phones.
   - **Automated Download Box:** 24/7 qBittorrent + *arr automation stack (Radarr/Sonarr) utilizing cheap night data.
   - **Private Cloud (Immich / Nextcloud):** Unlimited mobile photo/video auto-backup replacing iCloud/Google Drive.
   - **Password Vault (Vaultwarden):** Self-hosted Bitwarden server for family credentials.
   - **Home Assistant:** Central IoT automation hub that operates offline during internet blackouts.
   - **Local AI Inferences:** Small local LLM (Ollama, Whisper speech-to-text) for coding and private automation.
3. **Verdict on Network Speed:**
   A Mini-PC does NOT increase cellular tower speed, but when paired with Gigabit FTTH, it turns raw bandwidth into an all-in-one private cloud, entertainment hub, and zero-compromise security gateway.  
**Blocked by:** none  

## Question

Specifically, what practical utilities, software stacks, and capabilities does a refurbished Mini-PC (e.g. HP EliteDesk 800 G3/G4 with Core i5, 16GB RAM, NVMe SSD) provide for this exact home setup, and how does it compare to the current OpenWrt routers?

## Execution Plan

1. Analyze compute/memory difference (x86_64 Core i5 4-6 cores vs 2x A53 router SoC; 16-32GB RAM vs 256MB).
2. Detail core workloads:
   - High-throughput zero-latency proxying (xray/sing-box with heavy multiplexing, hysteria2, WARP, transparent routing without dropping a single packet).
   - Proxmox VE hypervisor & Docker containerization.
   - Self-hosted services: Plex / Jellyfin media server, automated torrent/download machine, Nextcloud private cloud, Vaultwarden.
   - Local AI & LLM inferences (Ollama, local speech-to-text Whisper, embedding models).
   - AdGuard Home / Pi-hole with multi-million domain blocklists.
3. Quantify power consumption, footprint, and daily operational reality.
