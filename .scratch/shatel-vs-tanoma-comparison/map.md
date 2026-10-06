# Map: Shatel Fiber vs. TCI Tanoma Exhaustive Comparative Analysis

**Effort:** `shatel-vs-tanoma-comparison`  
**Label:** `wayfinder:map`  
**Tracker:** Local Markdown (`.scratch/shatel-vs-tanoma-comparison/issues/`)

## Destination

Produce an exhaustive, evidence-backed comparative dossier evaluating **Shatel Fiber (FTTH)** vs **TCI Tanoma (FTTH)** across:
1. Tariffs, price per GB, hardware (ONT) lock-in, and renewal costs.
2. Filtering, censorship aggression, DPI behaviors against VLESS/Reality/Hysteria2, CGNAT policies, and IP pools.
3. Gaming pings, international routing, packet loss, and jitter.
4. Field support SLA, fiber cut repair times, and real user sentiment from Twitter/X and tech communities.
5. Final operator recommendation customized for the 12-unit residential complex in Ponak, Tehran.

## Notes

- **Primary Sources:** Operator tariff documents (TCI & Shatel), user field reports (X/Twitter, Persian tech forums, Hardware Persia, Zoomit communities), networking routing tables.
- **Location Context:** Tehran District 5 (Ponak, Shahid Nazari exchange).

## Decisions so far

- [01-tariff-and-pricing-deep-dive](issues/01-tariff-and-pricing-deep-dive.md): TCI Tanoma wins on base plans (from 190k T/mo, ~1,500 T/GB, postpaid on phone bill, BYO ONT modem). Shatel offers massive 2400GB bundled festivals (~20M T with modem) and installment plans.
- [02-filtering-dpi-and-vpn-behavior](issues/02-filtering-dpi-and-vpn-behavior.md): TCI Tanoma provides real dynamic public IPv4 by default (no CGNAT); Shatel puts residential clients behind CGNAT (needs paid Static IP). Both handle VLESS+Reality smoothly; Shatel is more aggressive on raw UDP.
- [03-routing-latency-and-gaming-performance](issues/03-routing-latency-and-gaming-performance.md): Shatel Fiber wins on gaming/latency with its dedicated FastPath gaming profile (68-85ms to Europe vs 85-115ms on TCI Tanoma) and tighter peak-hour queueing.
- [04-user-reviews-and-support-sla](issues/04-user-reviews-and-support-sla.md): Shatel wins decisively on customer support (24/7 call center, 12-24h fusion repair SLA vs 48-72h bureaucratic delays on TCI). TCI praised for cheap bulk traffic and public IP.
- [05-definitive-head-to-head-synthesis](issues/05-definitive-head-to-head-synthesis.md): Published definitive comparative dossier `docs/SHATEL_FIBER_VS_TCI_TANOMA_DEFINITIVE_GUIDE.md`. Recommended dual-track application; choose Shatel for gaming/SLA or TCI for public IP/cheap renewals.

## Frontier & Open Tickets

- [01-tariff-and-pricing-deep-dive](issues/01-tariff-and-pricing-deep-dive.md): Compare entry bundles, per-GB pricing, extra traffic rates, and hardware costs.
- [02-filtering-dpi-and-vpn-behavior](issues/02-filtering-dpi-and-vpn-behavior.md): Compare DPI aggressiveness, VPN protocol survivability, and Public IP / CGNAT allocation.
- [03-routing-latency-and-gaming-performance](issues/03-routing-latency-and-gaming-performance.md): Compare international routing hops, domestic IXP peering, and gaming latency.
- [04-user-reviews-and-support-sla](issues/04-user-reviews-and-support-sla.md): Gather real-world user feedback from X/Twitter and community forums regarding uptime, support, and fiber cuts.
- [05-definitive-head-to-head-synthesis](issues/05-definitive-head-to-head-synthesis.md): Deliver final verdict, scorecards, and deployment recommendation.

## Not yet specified

- Secondary operator alternatives (Irancell FTTH, Asiatech).

## Out of scope

- Point-to-point wireless or ADSL2+.
