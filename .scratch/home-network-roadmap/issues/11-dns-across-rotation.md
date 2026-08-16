# 11 — DNS stays proxied + ad-blocked across rotation

**What to build:** DNS queries keep going through the active node's path and ad-blocking keeps applying when the failover chain rotates or fails open — no direct-DNS leak during fallback, so privacy and ad-blocking survive degraded mode.

**Blocked by:** None — can start immediately (verify against 04 after it lands).

**Status:** in-progress (dns-ensure.sh deployed; encrypted-DNS rung BLOCKED: firmware has no package manager to install the DoH stub; ad-block holds across rotation)

- [ ] DNS follows the active node across rotation.
- [ ] Ad-blocking applies in degraded and fail-open windows.
- [ ] A leak check confirms no direct-DNS escape during fallback.
