# 04 — Frontend React dashboard

**What to build:** A React single-page application built from the existing web/ skeleton (Vite + Tailwind + TypeScript) that renders a dark-themed household network dashboard. Sections: Status overview (health verdict, signal bars, proxy state, devices count), Ledger table (per-person bars + GB/Toman), Device manager (list with owner assignment buttons), Budget card (remaining GB, drain rate, projected exhaustion), Outage history, Rescue pool status, Action buttons (switch ISP, reboot, toggle rescue/adblock) with confirmation modals for destructive actions. Polls /api/*.json every 30 s.

**Blocked by:** 01 (needs data snapshots), 03 (needs action endpoints).

**Status:** ready-for-agent

- [ ] Dark theme consistent with bot card aesthetic
- [ ] Status section: health verdict badge + signal bars + operator + uptime + temp + devices count
- [ ] Ledger section: per-person bars + GB + Toman, sorted desc, Persian month title
- [ ] Devices section: hostname + IP + MAC + owner, tap-to-assign via dropdown or inline edit
- [ ] Actions: confirmation modal before reboot/ISP switch; instant feedback for safe actions
- [ ] Polls every 30 s; shows "last updated" timestamp; handles fetch errors gracefully
- [ ] Mobile responsive (works on phone browser at 375px width)
