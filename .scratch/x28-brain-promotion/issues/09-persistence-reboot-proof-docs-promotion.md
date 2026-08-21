# 09 — Persistence, reboot proof + docs promotion

**What to build:** The closing proof that the promotion is real and
permanent: with everything from tickets 03–08 deployed and enabled, a
full X28 reboot brings the entire brain back unattended — proxy, DNS
chain + ad-blocking, operator watchdog + alerts, remote-control bot,
balance, usage/billing, API — verified by the health gate and a live
check of each piece after boot. The rollback snapshot is refreshed (the
restore drill re-verified against the new state), and the repo docs are
updated to the new world: the X28 is the brain; the AX3000T's recovery is
re-scoped to return as an AP/secondary, not as the control plane.

**Blocked by:** 04 — Telegram remote control; 05 — DNS ad-blocking;
06 — Samantel balance on the X28; 07 — Per-device usage + Toman billing;
08 — Router API re-host + Xirouter app.

**Status:** ready-for-agent

- [ ] A full reboot, unattended, returns every service healthy: health
      gate green post-boot plus a per-service live check (one Telegram
      round-trip, one balance read, one usage read, one API call, one ad
      domain blocked).
- [ ] Every new service is procd-managed and boot-enabled — no manual
      starts needed after reboot.
- [ ] The rollback snapshot is refreshed for the new state and the
      restore drill re-verified read-only.
- [ ] The glossary (CONTEXT.md), architecture doc and READMEs reflect the
      promotion: X28 = brain/control plane, AX3000T = future AP/secondary
      pending its UART recovery; the promotion spec records what
      superseded what.
