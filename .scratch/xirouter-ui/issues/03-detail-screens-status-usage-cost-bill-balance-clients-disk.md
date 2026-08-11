# 03 — Detail screens (Status, Usage, Cost, Bill, Balance, Clients, Disk)

**What to build:** all seven detail screens are rewritten to use the shared component library (Panel, Band, SectionHead, RowTitle, RowAmount, DetailRow, Gauge, StatusPill). Each screen follows the same polished pattern: a top bar with back arrow, section headings with asymmetric air, band-styled data rows, and Persian-digit ModamFigures for all numbers. The Balance screen's gauge uses the new arc component; the Clients screen's rename dialog uses the new text field styling with Radius.field. Every label is in Persian, every figure uses ModamFigures + tnum, and all spacing uses the Space token scale.

**Blocked by:** 01, 02

**Status:** ready-for-agent

- [ ] Status screen: uptime, load, RAM, temp, disk, proxy — all using DetailRow + StatusPill for proxy state
- [ ] Usage screen: per-device table using Band rows, RowTitle (device name) + RowAmount (GB), SectionHead with "امروز/این ماه" label
- [ ] Cost screen: per-device table with name, GB, Toman (ModamFigures + Persian grouping), share %, total line; uses Band
- [ ] Bill screen: same pattern as Cost but for the monthly period
- [ ] Balance screen: Gauge component for balance %, main plan details, expiry, drain, series sparkline (LineChart from Charts.kt — use the current simple version for now, full polish in ticket 04)
- [ ] Clients screen: device list using Band, RowTitle (name) + RowAmount (today GB), watch badge; rename dialog restyled with Radius.field text field
- [ ] Disk screen: Gauge for disk %, storage details
- [ ] All screens compile; data flows unchanged; every surface looks like a chandtoman sibling
