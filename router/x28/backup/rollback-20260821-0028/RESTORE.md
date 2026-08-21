# Rollback snapshot 20260821-0028 — restore procedure

Ticket 01 of the x28-brain-promotion. Taken while the X28 was fully
healthy (proxy 200 proxied + 200 direct, DNS clean, watchdog alive).
Nothing was restarted or modified to take it.

## What exists where

| Copy | Location | Contents |
|---|---|---|
| Device tarball (root-only, 600) | `/data/proxy/backup/rollback-20260821-0028.tar.gz` (~20 KB) | Everything below **plus the real xray configs and the v2raya DB** (secrets) |
| Repo copy (secret-free) | `router/x28/backup/rollback-20260821-0028/` | All scripts, init files, generated-config + iptables/ps/opkg state dumps, and **redacted** xray configs (`tmp/rollback-redacted/`), with `MANIFEST.sha256` |

Not snapshotted (immutable by every promotion ticket, unchanged since
deploy): the xray / xray.stock / v2raya / sing-box binaries and the
geoip/geosite data files on `/data/proxy`.

## Restoring (only if a later ticket breaks the box)

```sh
# on the X28, as root — extract over / (files land at their absolute paths)
tar xzf /data/proxy/backup/rollback-20260821-0028.tar.gz -C /
# then re-apply the live rules from the restored scripts
sh /data/proxy/tproxy-fixed-enable.sh
sh /data/proxy/dns-fix.sh
/etc/init.d/x28-watchdog restart
```

The tarball stores paths with the leading `/` stripped, so `-C /` puts
every file back where it came from. Live-DB files (`v2raya.db`,
`watchdog.log`) are snapshotted but expected to drift; restoring them is
harmless (v2rayA re-reads its DB on restart).

## Drill evidence (read-only, performed 2026-08-21 00:29)

- Extracted the device tarball to a scratch dir and `cmp`-verified every
  file against its live original: **30 identical, 0 mismatches**
  (2 live files skipped as expected drift: the v2raya DB, watchdog log).
- Health before and after the snapshot + drill, identical and green:
  proxied fetch via SOCKS 1080 → 200, direct exempted host → 200,
  dnsmasq answering (rcode 0), operator watchdog alive.
- Repo copy scanned for all known secrets (UUID/keys/passwords): clean —
  only `__PLACEHOLDER__` / `__VLESS_UUID__` markers in the redacted
  configs.
