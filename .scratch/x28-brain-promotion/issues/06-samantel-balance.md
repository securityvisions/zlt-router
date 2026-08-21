# 06 — Samantel balance on the X28

**What to build:** The data-plan balance feature the AX3000T provided,
rebuilt on the X28: a scheduled read-only query of the Samantel PWA API
(remaining GiB from the Remain fields, quota, expiry, drain rate),
cached in a state file, surfaced as a `/balance` card through the bot and
as a low-balance alert when a threshold is crossed. Fetch failures degrade
silently (cached value + a log line) — never alert spam, never an impact
on the proxy path. Needs the Samantel credential (human-gated
prerequisite), stored root-only on the device.

**Blocked by:** 03 — Status collector + Telegram alerts.

**Status:** ready-for-agent

- [ ] The `/balance` card shows remaining GiB, quota, expiry and drain
      rate matching the Samantel PWA figures.
- [ ] Scheduled fetches (procd timer) refresh the cache; a failed fetch
      keeps the previous values and logs without alerting.
- [ ] The low-balance alert fires once per threshold crossing (no repeat
      spam while below).
- [ ] Balance history rows are appended (the series the drain-rate and
      future charts read).
- [ ] The health gate is green after deployment; credentials exist only
      in the root-only config on the device.
