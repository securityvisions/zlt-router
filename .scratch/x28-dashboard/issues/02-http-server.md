# 02 — busybox httpd on :8080 (LAN-only)

**What to build:** A busybox httpd instance bound to 192.168.70.1:8080 serving static files from `/data/proxy/dashboard/www/` and CGI scripts from `/data/proxy/dashboard/cgi/`. Runs as a procd service (`x28-dashboard`). The vendor mini_httpd on :80/:443 is completely untouched. LAN-only enforced by binding + firewall rule addition.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] busybox httpd running on 192.168.70.1:8080 via procd init script
- [ ] Serves static files from document root; CGI enabled for action endpoints
- [ ] harden.sh extended: port 8080 added to X28_MGMT firewall chain (WAN drops)
- [ ] Vendor mini_httpd on :80/:443 confirmed still working after deployment
- [ ] Dashboard reachable from workstation browser at http://192.168.70.1:8080
- [ ] Rollback verified: stop service + remove init = zero trace
