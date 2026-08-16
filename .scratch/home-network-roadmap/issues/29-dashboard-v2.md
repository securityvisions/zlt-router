# 29 — Dashboard v2 (capstone)

**What to build:** The dashboard becomes a real operations console: widgets that reorder, hide, and resize with the size actually changing the card; configurable quick actions; a person mini-dashboard (usage, estimated cost, payment state, devices, trend, quota progress, previous months); and named user-saved layouts over presets.

**Design requirement — use the `ui-ux-pro-max` skill.** Before building the widget catalog, quick actions, or the person mini-dashboard, load the `ui-ux-pro-max` skill and drive the design from its intelligence: palette, typography, Jetpack Compose guidance, and the product-type profile for an operations dashboard. This is a hard requirement of this ticket, not a suggestion.

**Blocked by:** 21 — Payments ledger + person credit; 22 — Quotas + crossing events; 23 — Activity timeline + permanent audit; 24 — Device enrichment + ownership suggestions; 28 — Forecasting + insights

**Status:** in-progress (dashboard v2: quick actions, forecast/insights card, link card; full widget-catalog polish pending)

- [ ] Widget catalog v1 (collection, ranking, metrics, live, package+forecast, balance mini, monthly, unpaid, quick actions, insights, activity); `SizeVariant` actually changes the card.
- [ ] Quick actions: register payment, add person, assign device, refresh, live, proxy.
- [ ] Person mini-dashboard shows usage, estimated cost, payment state, devices, trend, quota progress, and previous months.
- [ ] Layouts: presets seed them; user-saved named layouts persist.
- [ ] The `ui-ux-pro-max` skill is loaded and its guidance is reflected in the shipped design.
