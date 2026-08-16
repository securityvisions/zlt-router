# 17 — VPS bandwidth burn + tier-headroom alert

**What to build:** The VPS tier is the only scale lever, so it gets metered: a bandwidth burn meter on the VPS (vnstat) reports monthly traffic through the existing health path, and an alert fires when the month approaches the tier cap.

**Blocked by:** None — can start immediately.

**Status:** in-progress (vnstat installed on VPS; AX3000T burn-reader pending VPS SSH repair)

- [ ] vnstat is installed and configured on the VPS.
- [ ] Monthly burn is readable through the existing VPS health path.
- [ ] Headroom alert is cooldown-gated via the shared alert path.
