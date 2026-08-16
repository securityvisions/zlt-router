# 20 — Automation rules

**What to build:** Serializable WHEN/IF/THEN automation rules — "package below 15% → notify me" — with a visual builder, enable/disable, and run history. The engine evaluates after each poll cycle and on app foreground; the notify action writes an inbox row.

**Blocked by:** 18 — Room v5→v6 migration spine; 19 — Inbox

**Status:** resolved (AutomationEngine + versioned envelope + tests; runner wired on poll)

- [ ] Engine fires on the crossing (false→true) and does not re-fire while true.
- [ ] Enable/disable is respected; run history is recorded.
- [ ] The notify action writes exactly one inbox row.
- [ ] Versioned JSON round-trip skips unknown subtypes.
- [ ] Visual builder UI.
