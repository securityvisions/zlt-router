# 06 — VPS sing-box self-heal (on the VPS)

**What to build:** Today a hung sing-box core waits for the X28 to notice (minutes) before the panel restart fires. This ticket moves first response onto the VPS itself: a systemd timer (or equivalent) that checks the core's local health and restarts it within ~1–2 minutes of death — independent of, and faster than, the X28-side heal loop (which remains as second line). Requires working SSH to the VPS; if the DPI-stall blocks direct SSH, the setup is performed through the tunnel.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] Health check runs on the VPS every minute: core process alive AND its inbound answers locally (cheap self-probe), else restart via the panel's own service mechanism
- [ ] Restart action logged on the VPS with timestamp; consecutive-restart cap prevents crash-loops (after N rapid restarts it stops and alerts instead)
- [ ] Idempotent installer script committed to the repo; re-running upgrades/repairs rather than duplicates
- [ ] Live verification: deliberately stop the core on the VPS → it self-recovers within ~2 min without any X28 involvement → Reality path healthy again from a LAN client
- [ ] X28-side heal loop still functions as backstop (its longer threshold unchanged by this ticket)
