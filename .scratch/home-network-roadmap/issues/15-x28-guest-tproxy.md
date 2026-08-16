# 15 — Enable X28 guest/backup network tproxy

**What to build:** A device on the X28's LAN gets proxied internet even when the AX3000T is offline — the tproxy enable/disable scripts already exist; this ticket wires, verifies, and toggles them on as the backup network.

**Blocked by:** None — can start immediately.

**Status:** in-progress (tproxy scripts verified on X28; opt-in toggle pending user decision)

- [ ] An X28-side device has internet with the AX3000T unplugged.
- [ ] The backup path is reversible via the disable script.
- [ ] Enabled live as an opt-in change.
