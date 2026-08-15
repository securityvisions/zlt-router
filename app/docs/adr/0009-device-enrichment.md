# ADR-0009: Device enrichment

**Status**: Accepted (wayfinder ticket #11, informed by the API gap analysis #2)

## Context

Devices carry only MAC/alias/category/note/owner/watch/hide. The vision requires IP, last-seen/online state, device type, tags, and privacy exclusions (billing/analytics/notifications). The API gap analysis (#2) found: IP+hostname covered (`/clients`), online ≈ lease presence, **no real last-seen timestamp** exposed (gap), no per-device history (gap).

## Decision

- `DeviceSettingsEntity` gains: `ip` (TEXT default `""`), `deviceType` (TEXT default `""`, user-set), `tags` (TEXT default `""`, comma-separated), `lastSeenUnix` (LONG default 0), `excludeFromAnalytics` (INT default 0).
- On each poll cycle: `ip` and presence update from `/clients`; when a device is present, `lastSeenUnix = now`. Online state is derived (present in `/clients`). No new router endpoint required for v1 — last-seen is local-derived from poll presence (the honest approximation the gap analysis named).
- Privacy: billing exclusion = existing `hideFromLedger`; analytics exclusion = new `excludeFromAnalytics` (drops the device from ranking/insights/history charts); notification exclusion = the existing per-kind toggles (device-level notification mute deferred).
- Device type auto-inference from MAC OUI deferred (fog) — type is user-set in v1.
- Migration v6 adds the columns.

## Consequences

- Last-seen is "last seen by the app's polls", not the router's lease timestamp — documented in the UI copy.
- The two true router gaps (per-device history, real last-seen) remain approximate until the router repo adds endpoints; the app degrades gracefully.