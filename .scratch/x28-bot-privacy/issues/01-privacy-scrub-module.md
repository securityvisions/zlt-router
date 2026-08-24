# 01 — Privacy scrub module

**What to build:** A `privacy-lib.sh` module holding the toggleable privacy state (`/data/proxy/privacy.conf`, `PRIVACY=1`) and a `privacy_scrub` filter that masks sensitive values generically — MAC addresses, IPs, owner names (from the owners file), and device hostnames (from live leases) — replacing them with neutral placeholders. When privacy is off it passes text through untouched. Demoable standalone via CLI: toggle on, scrub a sample card, see it masked; toggle off, passthrough.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] Module exposes privacy_on / privacy_toggle / privacy_state and a scrub function
- [x] Scrub masks MACs, IPs, owner names, and device hostnames when on; passthrough when off
- [x] State file and owner/lease sources are env-overridable for fixture testing
- [x] Fixture test: masked MAC/IP/name/hostname in a sample card; passthrough when privacy off