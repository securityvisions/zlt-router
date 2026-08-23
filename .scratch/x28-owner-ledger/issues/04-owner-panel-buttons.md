# 04 — Owner Panel: tap-to-assign button flow

**What to build:** `/owner` opens an Owner Panel Card plus inline keyboard driven entirely by friendly names: unassigned devices as tappable buttons (hostname-first, MAC only in code detail), person buttons with device counts, two-step assign (tap device → tap person → applied instantly with confirmation edit). Callback state machine uses short refs into a generation state file so Persian/spaced names fit Telegram's 64-byte callback limit; taps are staleness-guarded and acked instantly. Text fallbacks stay and now accept HOSTNAME or MAC (`/owner assign Nothing-Phone-2 maman`); `/owner rename <old> <new>` relabels every device of a person in one shot; unassigned devices are surfaced proactively in the panel header.

**Blocked by:** 01 — needs the granular rollups for device counts.

**Status:** ready-for-agent

- [ ] Callback payloads parsed/validated pure + unit-tested (incl. stale/tampered refs, TTL cleanup of state files)
- [ ] Full flow works on mobile: /owner → tap device → tap person → confirmation edit, zero typing
- [ ] Hostname-or-MAC accepted by text fallback; invalid input gets usage guidance, never silence
- [ ] /owner rename atomically relabels all devices of a person; list reflects instantly
- [ ] Panel greps/assertions updated; deployed; live smoke of assign→list→rename; health gate GREEN
