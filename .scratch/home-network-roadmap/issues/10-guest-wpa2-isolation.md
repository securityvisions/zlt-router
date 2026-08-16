# 10 — Guest network WPA2 + isolation

**What to build:** The guest SSID (XI-Guest) stops using mixed WPA and becomes WPA2-only with LAN isolation, so guest devices can reach the internet but never the home LAN. Opt-in: it is toggled on deliberately, not force-enabled.

**Blocked by:** None — can start immediately.

**Status:** resolved (XI-Guest WPA2-only psk2 + isolate=1; verified live)

- [ ] XI-Guest is WPA2-only.
- [ ] Guest clients cannot reach the home LAN.
- [ ] Enabled live as an opt-in change.
