# 19 — Inbox

**What to build:** An in-app inbox with unread / read / acknowledged states triages the alerts that already exist (poll events, package alerts, automations, mutations). A shared recorder writes them; per-kind mute toggles exist; the UI has an unread badge and filters.

**Blocked by:** 18 — Room v5→v6 migration spine

**Status:** resolved (InboxKeeper + inbox_events + UI flow; state/seam tested)

- [ ] Shared inbox recorder is used by poll events, package alerts, automations, and mutations.
- [ ] Unread / read / acknowledged states and an unread badge.
- [ ] Per-kind mute toggles.
- [ ] Persian-first UI.
