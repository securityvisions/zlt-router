# 04 — Nightly config backup + drift alert

**What to build:** Silent config erosion (the lan_mgr class of incident) is a reliability threat: a rewritten dnsmasq stanza or proxy conf can degrade the path without anything crashing. This ticket adds a nightly job that snapshots the critical configuration set into `/data` and diffs it against the last-known-good copy; any unexpected drift sends one Telegram alert listing exactly which files changed. Restoring stays the existing snapshot/rollback drill.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [ ] Nightly snapshot (procd loop, age-based like the adblock refresh — no cron) of the critical config set: proxy engine conf, boot script block, hotplug hook, DNS-relevant state markers, secrets files' **hashes only**, owner map
- [ ] Drift detection compares against last-known-good hashes; unexpected change → single alert card naming the changed files; expected self-healing changes (dns-fix mode flips) are whitelisted, not alerted
- [ ] Last-good pointer advances only after an alert was sent or an explicit acknowledge command runs (so drift can't be silently swallowed by the next snapshot)
- [ ] Snapshots bounded (keep last N nights); everything under `/data`, survives reboot
- [ ] Diff/whitelist decision logic pure + unit-tested with fixture file sets; deployed with health gate GREEN; live exercise: touch a tracked file → exactly one drift alert naming it
