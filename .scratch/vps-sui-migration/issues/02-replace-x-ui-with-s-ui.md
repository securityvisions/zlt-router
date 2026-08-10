# 02 — Replace the x-ui panel with s-ui

**What to build:** x-ui is stopped, disabled, and removed; the s-ui panel (sing-box core) is installed with its default panel/subscription ports and freshly generated random admin credentials; the panel is reachable and the old panel port is closed in the firewall. The new panel is up and administrable.

**Blocked by:** 01

**Status:** ready-for-agent

- [ ] x-ui service is stopped, disabled, and its files moved into the backup
- [ ] s-ui is installed and both its services (panel + sing-box core) are running
- [ ] The panel is reachable on its default port/path and admin login works with the generated credentials
- [ ] The old panel port is removed from the firewall and the new panel port is allowed
