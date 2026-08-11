# 05 — Live bandwidth + Actions + Settings

**What to build:** the remaining three screens are polished: Live bandwidth uses a new LiveRateCard composable (large ModamFigures number + pulse animation + up/down arrows), the Actions screen uses Panel/Band for URL test, proxy switch, and reboot with confirm dialogs restyled in the new tokens, and the Settings screen uses Panel/Band for connection fields, Friday toggle, notification toggles, and app lock. The Live screen's polling loop uses the new dark theme and the streaming-area chart style for the throughput graph.

**Blocked by:** 01, 02

**Status:** ready-for-agent

- [ ] LiveRateCard created: large ModamFigures number (displayMedium), animated pulse/glow on update, up/down arrow indicators (TrendCaret), total throughput label
- [ ] Live screen rewritten: LiveRateCard for total, per-device list using Band + RowTitle + RowAmount, streaming area chart for throughput history
- [ ] Actions screen rewritten: Panel for URL test (text field + button + result), Panel for proxy switch (StatusPill showing current node + switch button with confirm dialog), Panel for reboot (confirm dialog with warning text)
- [ ] Settings screen rewritten: Panel sections for Connection (address + token fields), Notifications (toggle rows with StatusPill-style styling), App Lock (toggle + PIN setup dialog)
- [ ] All screens compile; Live screen polling works without stacking (await pattern); Actions and Settings use new tokens/font/colors
