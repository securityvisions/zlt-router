# 07 — Second live tunnel path

**What to build:** End the single-server ceiling: get a second independently-usable node into the `auto` rotation and verify it through the controller.

**Blocked by:** None technically — **blocked externally** (see findings).

**Status:** resolved (with caveat)

## Findings (2026-08-22, live)

| Node | State | Evidence |
|---|---|---|
| vps-reality | ✅ working | controller delay=768–976 ms; carries all traffic now |
| babaii | ❌ handshake fails | TCP :23993 OPEN again (server rebooted), but delay-test errors **both with AND without `flow: xtls-rprx-vision`** — provider-side user/UUID/protocol likely rotated |
| cdn-ws | ❌ origin down | Cloudflare edge up, origin :8443 timeout (not ours) |
| hy2 | ⚠️ flapping | UDP :31800 throttled/lost on MCI path; alive flag oscillates, explicit delay errors |

Config was exercised both ways during testing (flow removed → re-added); live file matches repo template; validated with engine config-test; health stayed GREEN throughout.

## What unblocks each route

1. **babaii**: check its provider panel — confirm protocol (vision vs plain), current UUID/port for our user → I update one stanza and re-verify in minutes.
2. **Second VPS**: any cheap box reachable from here over SSH → I deploy Reality inbound + add node.
3. **cdn-ws**: origin server at dmbz.ir must come back up (external).

Until one lands, single-path ceiling stands — mitigated by tickets 01/05/06 (faster switch, bearer bounce, dual-vantage core heal).

## Comments (update 2026-08-22 late)

Live per-node delay tests now show **three working paths**: vps-reality 777 ms, cdn-ws 1463 ms, hy2 1570 ms — the acceptance ("≥2 genuinely alive nodes verified through the controller") is met at this timestamp. Caveat: cdn-ws/hy2 have flapped historically (origin outages / MCI UDP throttling), and babaii still needs its provider panel checked. Watchdog + dual-vantage heal cover the flaps either way.
