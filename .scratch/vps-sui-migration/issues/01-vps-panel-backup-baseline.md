# 01 — VPS panel backup & rollback baseline

**What to build:** A complete snapshot of the current x-ui panel state on the VPS (database, generated config, core binaries) plus a proven restore path, so every later change in this effort is revertible in minutes. Nothing on the live server changes.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] A timestamped backup of the x-ui panel state (database, config, core binaries) exists on the VPS before any change
- [ ] A JSON reference dump of the proxy inbounds is included (clients, credentials, traffic caps)
- [ ] The restore path is verified to return the server to the pre-change state
- [ ] The backup location and restore command are documented
