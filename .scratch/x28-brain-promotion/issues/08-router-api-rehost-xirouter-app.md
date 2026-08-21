# 08 — Router API re-host + Xirouter app

**What to build:** The Router JSON API re-hosted on the X28 so the
Xirouter app works again: a token-gated (HTTP Basic, same contract)
read-surface serving live status, link, balance, usage and device data
from the same state files the bot reads, reachable on the LAN, with the
app repointed at the X28's address and its screens (status, balance,
usage, devices) rendering live data. The X28 runs no stock web daemon, so
the hosting choice is made at build time with one hard rule: whatever is
chosen must not modify or bind the vendor's web panel — a small separate
listener is the default.

**Blocked by:** 03 — Status collector + Telegram alerts; 06 — Samantel
balance on the X28; 07 — Per-device usage + Toman billing.

**Status:** ready-for-agent

- [ ] The API answers on the LAN with live data for status/link/balance/
      usage/devices from the shared state files.
- [ ] Requests without the token are rejected; the token lives root-only
      on the device (never in the repo or app source).
- [ ] The hosting arrangement is documented and provably does not touch
      the vendor web panel or its ports.
- [ ] The Xirouter app, repointed to the X28, shows live status, balance,
      usage and devices.
- [ ] The health gate is green after deployment.
