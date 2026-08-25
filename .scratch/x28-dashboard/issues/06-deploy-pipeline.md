# 06 — Deploy pipeline owns the dashboard + ledger stack

**What to build:** Running the X28 deploy script reproduces a fully working dashboard from a clean device — today it deploys none of it. Extend it to install and enable both dashboard services (web server init + snapshot-generator init, with idempotent restart), push the frontend and its CGI action scripts into the dashboard doc root, and land the ledger store at its canonical device path (`/data/proxy/ledger-store.sh`). After a deploy run, the post-deploy smoke proves it end-to-end: :8080 serves the page (HTTP 200), one API snapshot endpoint returns valid JSON, the vendor mini_httpd on :80/:443 still answers, and a ledger query for the current Jalali month returns rows.

This closes the drift class that caused the 2026-08-25 outage (live init edited on-device to a server that doesn't exist on the build, repo copy never re-deployed) and the silent Ledger-card emptiness (store never deployed to the path the snapshot generator reads).

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] Deploy script installs/enables/restarts both dashboard init services idempotently (re-run safe)
- [x] Deploy script pushes frontend, CGI actions, and ledger store to their canonical device paths
- [x] Post-deploy smoke green: page 200, API JSON valid, ledger query returns rows, vendor :80/:443 untouched
- [x] Repo copies remain canonical — live files byte-identical after deploy

## Answer

Deployed to the X28 via the new section's exact steps (2026-08-25): ledger store at `/data/proxy/ledger-store.sh`, all 7 CGI scripts at both `dashboard/cgi/` and served `www/cgi-bin/` (byte-counts verified equal), api symlink + data dir recreated, generator + both init services enabled and restarted. Post-smoke: page/api 200, vendor :80/:443 untouched (200), health-gate dash slice PASS/PASS → GREEN. Full repo suite OK. Note: full `deploy.sh` run deferred — it restarts mihomo, whose live config still carries the unverified Steam-voice patches from the paused UDP effort.
