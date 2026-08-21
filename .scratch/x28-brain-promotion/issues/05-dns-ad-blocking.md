# 05 — DNS ad-blocking

**What to build:** LAN-wide ad/tracker domain blocking at the X28's
existing dnsmasq — no new DNS server, no binary replacement. A maintained
blocklist on the persistent volume feeds an include that survives the
vendor's config regeneration and the established full-restart + hotplug
reapply pattern; a weekly procd-timer refresh keeps the list current. The
anti-poisoning tunnel upstream chain must remain exactly as it is — the
blocking is additive only. Verify from a LAN client: a known ad domain is
blocked while normal domains and the proxied path stay green.

**Blocked by:** 02 — Dependency install + x28-health gate.

**Status:** resolved (93,512-domain StevenBlack list live; `dns-fix.sh` owns the
guarded include; `x28-adblock` procd service refreshes weekly; ~12 MB RAM cost;
health gate GREEN throughout — wipe-and-reapply drill proven)

- [x] From a LAN client, a known ad domain resolves to the blocked
      address while ordinary domestic and international domains resolve
      normally. (Blocked names return no A record — unusable, which is
      the block; google + the direct-exception host resolve their real
      IPs.)
- [x] The tunnel DNS upstream chain is unchanged and the proxied path
      still returns 200 (health gate green).
- [x] The blocking include survives a vendor dnsmasq regeneration, the
      DNS-fix full restart, and a net hotplug reapply. (Simulated wipe →
      dns-fix re-apply restores include + override; idempotent reruns
      leave exactly one include line.)
- [x] The blocklist refresh runs on a weekly procd timer with a log line
      per run, and a manual refresh command works. (Loop daemon checks
      age hourly; manual run fetched through the box's own tunnel and
      atomically swapped 93,512 domains.)
- [x] Removing the include (documented one-liner) restores the previous
      DNS behaviour exactly. (`dns-fix.sh` strips the directive itself if
      the list file is absent — dnsmasq can never point at a missing
      file; full removal = restore the pre-ticket `dns-fix.sh` from the
      rollback snapshot.)
