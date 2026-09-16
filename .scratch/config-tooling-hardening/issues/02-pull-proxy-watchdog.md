# 02 - Pull proxy-watchdog.sh into the repo (close the no-canonical gap)

Status: resolved
Type: task

## Question

Pull `/usr/sbin/proxy-watchdog.sh` from AX3000T into `router/` (plus `router/axproxy.sh` if absent), update the ADR-0007 gap list, and record tonight's earlier hotfixes (uci add_list pattern) as the canonical copy.

## Notes

- Pure pull — no push anywhere (ADR-0007).
- The device copy already contains tonight's corrected `uci -q delete … add_list` pattern; that IS the canonical version.

## Answer

Pulled via `netpull pull proxy-watchdog` → router/proxy-watchdog.sh. The canonical copy includes tonight's corrected dnsmasq-upstream pattern (uci -q delete + add_list) and the usteer-era fixes. First `netpull status` after the pull reports 11/11 match across both devices.
