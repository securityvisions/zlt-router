# Rollback snapshot 20260825-2011 — restore procedure

Taken while the X28 was healthy (dashboard serving, health-gate dash slice
GREEN). Nothing was restarted or modified to take it beyond read-only pulls.
Ticket 01 of x28-insights-fairness.

## What exists where

| Copy | Location | Contents |
|---|---|---|
| Device tarball (root-only, 600) | `/data/proxy/backup/rollback-20260825-2011.tar.gz` (215 KB) | Everything below **plus the credential-bearing configs** (proxy engine config, tg/samantel confs) |
| Repo copy (secret-free) | `router/x28/backup/rollback-20260825-2011/` | All scripts, init units, dashboard files, usage/ledger data, generated-config + firewall/routing/service state dumps, with `MANIFEST.sha256` (authoritative count — run `x28-snapshot.sh verify` on it) |

Not snapshotted (immutable or regenerated at runtime): the proxy engine
binary and dir, xray / xray.stock / sing-box binaries, the v2raya dir
(binary + DB), geoip/geosite dat files (any variant), the jq binary,
volatile token/cache files, and the adblock lists (regenerate with
`sh /data/proxy/adblock/adblock-update.sh`). Secrets never enter the repo.

## Verifying this snapshot

```sh
sh router/x28/x28-snapshot.sh verify router/x28/backup/rollback-20260825-2011
```

## Restoring (only if a later change breaks the box)

```sh
# on the X28, as root — extract over / (files land at their absolute paths)
tar xzf /data/proxy/backup/rollback-20260825-2011.tar.gz -C /

# re-apply the live state captured alongside the files
sh /etc/init.d/x28-dashboard restart   # and any other custom services needed
sh /data/proxy/dns-fix.sh              # DNS mode per tunnel health
sh /data/proxy/harden.sh               # management firewall

# verify
X28_HEALTH_GROUPS=dash sh /data/proxy/x28-health.sh
```

The repo copy restores individual files: `ssh cat < local > remote` over the
mirrored path (dropbear has no sftp).
