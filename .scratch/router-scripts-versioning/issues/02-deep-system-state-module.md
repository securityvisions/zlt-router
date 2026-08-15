# 02 — Deep system-state module (hn_sys_state)
**What to build:** One shared module `hn_sys_state` in hnlib.sh (or a sibling lib) that reads
all seven live router metrics — load, memory, temperature, disk, uptime, proxy state, nlbw
totals — behind a single `key=value` interface, e.g. `hn_sys_snapshot` and thin per-field
accessors. All four callers switch to it: the API's `ra_load/ra_mem/ra_temp_c/ra_disk/
ra_uptime/ra_proxy_state/ra_nlbw_macs` (routerapi_lib.sh:92-126), the bot's inline reads
(botcmd.sh:113-126), the hourly snapshot's probe and nlbw sum (snap.sh:9-18), and the disk
parse in tg.sh:26. The SOCKS probe timeout/URL live in exactly one place. Tests cover the
module with fixture overrides and verify the bot dashboard, /status, /live and snap all render
the same values.
**Blocked by:** 01 — the whole system must be versioned before its state readers move
**Status:** ready-for-agent
