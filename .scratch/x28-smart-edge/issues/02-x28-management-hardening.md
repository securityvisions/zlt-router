# 02 — X28 management hardening

**What to build:** SSH/telnet/v2rayA on the X28 reachable only from the LAN, and the rules survive reboot. /data/proxy/harden.sh applied at boot from rc.local.

**Blocked by:** None — can start immediately

**Status:** resolved (commit 330c6a8)

- [ ] Management ports 22/23/2017 are dropped for non-LAN sources; rules persist across a reboot.
