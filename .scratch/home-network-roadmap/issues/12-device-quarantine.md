# 12 — Device quarantine

**What to build:** A new/unknown device is blocked from internet access until it is approved through the bot — extending the existing new-device alert into an actual gate. Opt-in, like the other security-model changes.

**Blocked by:** None — can start immediately.

**Status:** resolved (quarantine.sh + /approve + /quarantine bot commands; opt-in, not enabled)

- [ ] New/unknown device gets internet-blocked and triggers the bot approval flow.
- [ ] Approving from the bot unblocks the device.
- [ ] Enabled live as an opt-in change.
