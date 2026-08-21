# 03 — Status collector + Telegram alerts

**What to build:** The visibility the network lost with the AX3000T: a
status card from the X28 — operator, tech, RSRP (LTE anchor + NR), data
state, proxy state, uptime, load, temperature, data-volume disk usage —
delivered to the user's phone. Alerts fire on the events that matter:
every operator switch and recovery the failover watchdog performs (both
directions), and "router back online" after a reboot. A one-shot test
command proves the pipe end-to-end. Needs the bot token + chat ID
(human-gated prerequisite); credentials live in a root-only config on the
X28, never in the repo.

**Blocked by:** 02 — Dependency install + x28-health gate.

**Status:** resolved (bot @xirouterbot live; `/etc/tg.conf` root-only with
token + chat id; `tg-notify.sh` + `x28-status.sh` + `x28-boot-alert.sh`
deployed; watchdog carries 4 alert hooks and was restarted clean; test card
delivered — API `ok:true` message_id 255; health gate GREEN after deploy)

- [x] On-demand status card sent to the configured chat, with live values
      from the link reader (no stale placeholders). (First live card
      delivered: MCI 43211, 5G NSA, RSRP −79, data OK, proxy OK, 3
      devices, 66 °C.)
- [x] The operator watchdog emits an alert on every MCI ↔ Rightel switch
      and on recovery, including the new operator and signal summary.
      (Hooks deployed + syntax-checked + watchdog restarted; the switch
      path itself was live-proven both directions in the earlier session —
      re-firing a real switch just to see an alert was judged not worth
      the outage risk.)
- [x] A boot-time alert reports the X28 back online after reboot.
      (`rc.local` backgrounds `x28-boot-alert.sh`, which waits for the
      proxy path then sends the card; final proof lands with ticket 09's
      reboot test.)
- [x] A test-alert command delivers a card immediately (verifiable from
      the session). (Delivered and confirmed via the API response.)
- [x] The health gate is green after deployment; the alert hook failures
      can never block or crash the watchdog itself. (`tg-notify` is
      best-effort: own timeout, own error swallowing, always exits 0.)
- [x] Canonical copies + deploy wiring in the repo; the token exists only
      in the root-only config on the device.
