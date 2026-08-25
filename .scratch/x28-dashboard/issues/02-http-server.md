# 02 — LAN-only web server on :8080 (mini_httpd)

**What to build:** A second mini_httpd instance bound to 192.168.70.1:8080 serving static files from `/data/proxy/dashboard/www/` and CGI scripts from `/data/proxy/dashboard/cgi/`. Runs as a procd service (`x28-dashboard`). The vendor mini_httpd on :80/:443 is completely untouched. LAN-only enforced by binding + firewall rule addition.

**Note — busybox httpd is NOT available on this device:** the vendor busybox build has no `httpd` applet compiled in (`busybox httpd` → `httpd: applet not found`, exit 127). The repo's canonical `router/x28/x28-dashboard.init` therefore reuses the proven `/usr/bin/mini_httpd`. A live-config drift to `busybox httpd` broke the dashboard (crash-loop, no :8080 listener) and was reverted 2026-08-25.

**Blocked by:** None — mini_httpd binary already present (vendor uses it).

**Status:** resolved

- [x] mini_httpd running on 192.168.70.1:8080 via procd init script
- [x] Serves static files from document root; CGI enabled for action endpoints
- [x] harden.sh extended: port 8080 added to X28_MGMT firewall chain (WAN drops)
- [x] Vendor mini_httpd on :80/:443 confirmed still working after deployment
- [x] Dashboard reachable from workstation browser at http://192.168.70.1:8080
- [x] Rollback verified: stop service + remove init = zero trace

## Comments

> 2026-08-25 (outage fix): the busybox-httpd drift was reverted to the canonical mini_httpd init and all boxes above re-verified live **except rollback**, which was not re-exercised — left unticked until the next rollback drill.

> 2026-08-25 (rollback drill, ticket 01 of x28-insights-fairness): drill executed for real — stop + remove init reached **zero trace** (no :8080 listener, curl refused, vendor :80/:443 untouched), then redeployed purely from repo canonical copies. The drill also exposed that mini_httpd had been daemonizing outside procd tracking (an orphan survived `stop` and held :8080); fixed in the canonical init with `-D` (foreground) and proven managed — `stop` now removes the listener. Checkbox closed on this evidence.
