# 13 — Router API auth transport (X-Router-Token → HTTP Basic)

**What to build:** Deploy the Router API on the router (dispatcher, lib, token config, hourly
snapshot cron) and wire the app to it. The token is a shared secret in `/etc/routerapp.conf`.
This ticket covers the transport change forced by deployment reality, plus the status-code and
JSON-validity defects found while verifying.

**Blocked by:** 01

**Status:** resolved

- [x] Router API deployed on the router (`/www/cgi-bin/routerapi.sh` + `routerapi_lib.sh`, token
      in `/etc/routerapp.conf`, `/root/snap.sh` + hourly cron)
- [x] Auth works end-to-end: no/wrong token → 401, correct → 200, unknown path → 404
- [x] App sends Basic auth; rebuilt release APK (`~/router-app/dist/xirouter-v0.1.0.apk`)
- [x] All 13 endpoints return strictly valid JSON (strict parse gate added to the test harness)
- [x] ADR-0002, API contract, and the feature spec updated to match

## Answer

Deploying per the original contract (`X-Router-Token` header) failed: **uhttpd does not forward
custom `X-*` headers to CGI** — only a fixed whitelist (HTTP_ACCEPT, HTTP_COOKIE,
HTTP_AUTHORIZATION, HTTP_HOST, HTTP_REFERER, HTTP_USER_AGENT, …; confirmed from the binary's
strings). The token now rides the standard `Authorization` header as **HTTP Basic auth**
(username `xirouter`, token is the password). `ra_authed` accepts the Basic header (and keeps
the legacy `X-Router-Token` for back-compat / in-shell tests); `ApiClient` sends it.

Three adjacent defects were found and fixed while verifying:

1. **Dispatcher status loss** — `ra_route > file` runs in a subshell, so `RA_STATUS` never
   reached the dispatcher and every response was HTTP 200. `ra_route` now emits a trailing
   `@@STATUS:NNN` line (the lib's own marker convention) that the dispatcher strips to get the
   code, matching what the test harness already expected.
2. **uhttpd needs a reason phrase** — `Status: 401` alone is ignored (response stays 200);
   `Status: 401 Unauthorized` works. The dispatcher maps 400/401/404/500 to full phrases.
3. **`ra_json_bill` double closing brace** — `...total_toman":61000}}` broke the app's strict
   JSON decoder ("Expected EOF … but had }"). `jq` in the test harness tolerated the trailing
   `}`; a strict python3 parse gate was added to `assert_json_eq` so this class of bug fails
   the suite. `/bill` was the only affected endpoint.

Also hardened node resolution: `RA_NODES` defaults are now derived from the live UCI config
(remark → id), with fallback resolution by protocol (e.g. `hysteria2`) and the legacy alias
list, so `/proxy/switch` cannot target a stale id. `/status` node display falls back to the
node's own remark.

Files touched: `~/home-network/router/{routerapi.sh,routerapi_lib.sh}`, `~/home-network/router/
tests/{lib.sh,test_auth.sh}`, `docs/adr/0002-router-json-api.md`, `~/router-app/API_CONTRACT.md`,
`~/router-app/app/src/main/java/ir/parsavisions/xirouter/ApiClient.kt`, rebuilt APK. All 44
router-api tests pass; all 13 endpoints strict-valid; auth matrix (401/200/404/400) verified
over HTTP against the live router.
