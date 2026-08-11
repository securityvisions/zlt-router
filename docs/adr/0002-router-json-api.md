# Router JSON API served by uhttpd CGI with a shared token

The home network's only surface has historically been the Telegram bot: data lives in shell
scripts and state files on the router, and nothing on the LAN can read it except via SSH or the
bot. The Xirouter Android app (a richer, chart-driven companion) needs a machine-readable seam.
We added a **JSON HTTP API** served by the router's existing uhttpd, implemented as a small CGI
dispatcher (`/www/cgi-bin/routerapi.sh`) plus a pure builder library (`routerapi_lib.sh`), gated
by a shared token in a root-only config (`/etc/routerapp.conf`, header `X-Router-Token`). The
dispatcher shells out to the existing state files and scripts the bot already uses — one state,
two surfaces — and emits JSON via `jq`-compatible builders.

This was chosen over a long-running ash HTTP daemon (faster per-request, but hand-rolled HTTP
parsing is a new attack surface in shell), over Lua/uhttpd-mod handlers (a second language in a
shell-only stack), and over a VPS-hosted API (explicitly rejected: the user wants no VPS in the
path, and the router is behind double-NAT so the API is LAN-local; remote access is deferred to a
Cloudflare Worker relay that pushes snapshots out, which the plain-JSON seam supports unchanged).
TLS is deliberately absent on the LAN endpoint; it becomes relevant only when the relay lands.
The token is a single shared secret rather than per-device auth — the audience is one household
on a private LAN.

**Considered options:** uhttpd CGI shell (chosen), long-running ash daemon, Lua/uhttpd-mod,
VPS-hosted API (rejected — no-VPS requirement), no auth on the LAN.

**Consequences:** Every new endpoint is a shell function in `routerapi_lib.sh` plus a route line
in `ra_route`; the state-reading functions are the test seam (tests override them with fixtures
and assert JSON). The router serves cleartext HTTP on the LAN — acceptable for a home monitor,
and the app pins no certificate. The token must be provisioned manually on the router; a wrong
or missing token gets a 401. The API is read/write for bot state (`user-names`, `watchlist`,
`LAST_FRIDAY`), so the app and bot stay consistent by construction.
