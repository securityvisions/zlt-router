# Map: FTTH Fiber Deployment (Ponak) & Mini-PC Utility Analysis

**Effort:** `ftth-and-minipc-strategy`  
**Label:** `wayfinder:map`  
**Tracker:** Local Markdown (`.scratch/ftth-and-minipc-strategy/issues/`)

## Destination

Deliver an actionable, verified roadmap to:
1. Identify the telecom center, active FTTH operators (TCI Tanoma, Shatel, Irancell, etc.), and concrete steps for a 12-unit residential building in Ponak (facing Faraz Park) to pull fiber optic into the building.
2. Provide a rigorous, exhaustive breakdown of what a refurbished Mini-PC enables (capabilities, services, workloads) and evaluate the sequencing: whether to invest in Mini-PC or FTTH infrastructure first.

## Notes

- **Location:** Tehran, District 5, Ponak (پونک), opposite Faraz Park (جلوی پارک فراز), 12-unit newly built residential building.
- **Tools:** Camoufox browser MCP, official operator portals (TCI Tanoma, CRA iranfttx.ir, Shatel, Irancell).

## Decisions so far

- [01-ftth-ponak-coverage-and-center](issues/01-ftth-ponak-coverage-and-center.md): Identified serving telecom center (**مرکز مخابرات شهید نظری** for Ponak/Faraz Park) and active operators (TCI Tanoma + Shatel Fiber). Noted national CRA site `iranfttx.ir` certificate outage.
- [02-ftth-12unit-acquisition-process](issues/02-ftth-12unit-acquisition-process.md): Formulated 12-unit collective application protocol (0 Toman FAT/infrastructure subsidy, dual-track TCI Nazari + Shatel `021-91000911`, bridge ONT -> AX3000T topology).
- [03-minipc-utility-and-homelab-matrix](issues/03-minipc-utility-and-homelab-matrix.md): Exhaustive breakdown of Mini-PC utilities: multi-gigabit AES-NI proxy gateway, Plex/Jellyfin QuickSync transcoding, 24/7 automated download box, Immich/Nextcloud private cloud, Home Assistant, and local AI.
- [04-synthesis-and-investment-roadmap](issues/04-synthesis-and-investment-roadmap.md): Delivered definitive investment roadmap: Skip second cellular modem; initiate zero-cost FTTH collective survey immediately, then deploy Mini-PC as home cloud/media/proxy hub.

## Frontier & Open Tickets

- [01-ftth-ponak-coverage-and-center](issues/01-ftth-ponak-coverage-and-center.md): Identify telecom center, operator commitments, and coverage around Faraz Park Ponak.
- [02-ftth-12unit-acquisition-process](issues/02-ftth-12unit-acquisition-process.md): Map out the end-to-end acquisition process for a 12-unit residential building (FAT installation, drop cable, indoor wiring, cost sharing).
- [03-minipc-utility-and-homelab-matrix](issues/03-minipc-utility-and-homelab-matrix.md): Exhaustive capability breakdown of a refurbished Mini-PC (Proxmox, multi-gigabit proxy core, Docker, NAS, local AI).
- [04-synthesis-and-investment-roadmap](issues/04-synthesis-and-investment-roadmap.md): Strategic roadmap comparing timeline, budget, and impact of FTTH vs Mini-PC.

## Not yet specified

- Equipment selection for FTTH (GPON ONT bridge modem vs AX3000T WAN uplink).

## Out of scope

- ADSL or VDSL legacy copper technology.
