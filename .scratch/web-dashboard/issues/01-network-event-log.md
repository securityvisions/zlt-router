# 01 — Network Event log: shared recorder + /events API

**What to build:** The router keeps one structured, append-only Network Event log. A shared recorder command lets any script append an event with a catalog-validated kind (category + severity derived), timestamp, and actor. The API gains `/events` returning events newest-first with limit and category filters.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] `hn_event_catalog` / `hn_event_record` / `hn_event_list` live in hnlib.sh; unknown kinds are rejected.
- [ ] The log is bounded (pruned) and survives reboots.
- [ ] `/events?limit=N&category=C` returns valid JSON, newest-first, auth-gated.
- [ ] Router suite green: `test_events.sh` + `test_events_api.sh`.
