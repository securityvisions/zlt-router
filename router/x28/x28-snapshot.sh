#!/bin/sh
# x28-snapshot.sh — repeatable full-state rollback snapshots for the X28.
#
# The completeness proof behind every rollback point: what exists, checksummed,
# verifiable, restorable. Follows the Aug-2026 snapshot ritual:
#   - repo copy (secret-free): mirrored device paths + state dumps +
#     MANIFEST.sha256 + RESTORE.md
#   - device-side root-only tarball (/data/proxy/backup/rollback-<ts>.tar.gz):
#     everything above PLUS credential-bearing configs — secrets never leave
#     the modem
#   - binaries and immutable dat files are documented as unsnapshotted
#
# Modes:
#   manifest <dir>   emit sorted "sha256  ./rel/path" lines for a local tree
#                    (MANIFEST.sha256 itself never listed)
#   verify <dir>     recompute and compare against <dir>/MANIFEST.sha256;
#                    nonzero exit on any tampered/missing/unexpected file
#   capture          pull the X28's custom stack into ../backup/rollback-<ts>/
#
# Env seams: X28_HOST, X28_SSH_PASS (or X28_PASS) for capture.

set -u

HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)

mode_manifest() {  # manifest <dir> — sorted sha256 lines, MANIFEST excluded
    local root="$1"
    ( cd "$root" && find . -type f ! -name 'MANIFEST.sha256' \
        | LC_ALL=C sort \
        | while IFS= read -r f; do sha256sum "$f"; done )
}

mode_verify() {  # verify <dir> — recompute vs MANIFEST.sha256
    local root="$1" rc=0 tmp
    tmp=$(mktemp 2>/dev/null) || return 1
    mode_manifest "$root" > "$tmp" 2>/dev/null
    if diff -u "$root/MANIFEST.sha256" "$tmp" > /tmp/snapshot-diff.$$ 2>&1; then
        echo "verify: OK ($(grep -c . "$root/MANIFEST.sha256") files)"
    else
        echo "verify: FAILED"
        cat /tmp/snapshot-diff.$$
        rc=1
    fi
    rm -f "$tmp" /tmp/snapshot-diff.$$
    return $rc
}

ssh_run() {
    # X28_SSH_PASS is the working convention (sui-heal.conf); X28_PASS accepted
    # for parity with deploy.sh's naming — one secret, two documented names
    local pass="${X28_SSH_PASS:-${X28_PASS:-}}"
    sshpass -p "$pass" ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
        -o HostKeyAlgorithms=+ssh-rsa -o PubkeyAuthentication=no -o LogLevel=ERROR \
        "root@${X28_HOST:-192.168.70.1}" "$@"
}

# NOTE: keep the exclusion prose in generate_restore_doc in sync with the
# find filters here — they describe the same list from two angles.

# FILE_LIST — relative paths (no leading /) of everything worth restoring.
# Excluded from BOTH copies: prior backups, crypto-engine binaries/dirs
# (xray, xray.stock, sing-box, v2raya), immutable dat files, the jq binary,
# volatile token/cache files, and regenerable adblock lists.
device_file_list() {
    ssh_run "cd / && {
        find data/proxy -type f \
            ! -path 'data/proxy/backup/*' \
            ! -path 'data/proxy/mihomo/*' \
            ! -path 'data/proxy/sing-box/*' \
            ! -path 'data/proxy/v2raya/*' ! -path 'data/proxy/v2raya' \
            ! -path 'data/proxy/adblock/*' \
            ! -path 'data/proxy/xray' ! -path 'data/proxy/xray.stock' \
            ! -name 'geoip.dat' ! -name 'geosite.dat' \
            ! -name '*.dat' ! -name '*.dat.*' \
            ! -name 'jq' \
            ! -name '*token*' ! -name '*cache*' ;
        find etc/init.d -maxdepth 1 -type f -name 'x28-*' ;
        for f in etc/rc.local etc/dnsmasq.conf root/hnlib.sh; do
            [ -f \"\$f\" ] && echo \"\$f\"
        done ; } | LC_ALL=C sort > /tmp/x28-snaplist && wc -l < /tmp/x28-snaplist"
}

mode_capture() {
    # POSIX sh on purpose (run via `sh` from tests and docs); no set -e —
    # each capture step handles its own failure explicitly
    local ts dest n secrets
    ts=$(date +%Y%m%d-%H%M)
    dest="$HERE/backup/rollback-$ts"
    mkdir -p "$dest/state" || { echo "capture: cannot create $dest"; return 1; }

    n=$(device_file_list) || { echo "capture: cannot reach device"; rm -rf "$dest"; return 1; }
    [ "${n:-0}" -gt 0 ] || { echo "capture: empty file list"; rm -rf "$dest"; return 1; }
    echo "capture: $n files listed on device"

    # secrets tarball stays on the device, root-only
    secrets=$(ssh_run "cd / && { cat /tmp/x28-snaplist ;
        for s in data/proxy/mihomo/config.yaml etc/tg.conf etc/samantel.conf ; do
            [ -f \"\$s\" ] && echo \"\$s\"
        done ;
        [ -d etc/v2raya ] && echo etc/v2raya ;
        } | LC_ALL=C sort -u > /tmp/x28-secretslist ;
        tar czf /data/proxy/backup/rollback-$ts.tar.gz -C / -T /tmp/x28-secretslist \
        && chmod 600 /data/proxy/backup/rollback-$ts.tar.gz && echo TARBALL-OK")
    case "$secrets" in *TARBALL-OK*) ;; *) echo "capture: device tarball failed"; rm -rf "$dest"; return 1 ;; esac

    # repo copy: stream the secret-free set straight into mirrored paths
    ssh_run "tar czf - -C / -T /tmp/x28-snaplist" | tar xzf - -C "$dest" \
        || { echo "capture: pull failed"; rm -rf "$dest"; return 1; }

    # live-state dumps (routing/firewall/services as they stand right now);
    # a failed dump writes a visible marker, never an empty file that reads
    # like valid content
    state_dump() {
        local f="$1"; shift
        if ssh_run "$*" > "$dest/state/$f" 2>/dev/null && [ -s "$dest/state/$f" ]; then
            :
        else
            echo "(capture failed on device during snapshot $ts)" > "$dest/state/$f"
        fi
    }
    state_dump iptables.save 'iptables-save'
    state_dump ip-rules.txt 'ip route show; ip rule show'
    state_dump services.json 'ubus call service list'
    state_dump opkg.txt 'opkg list-installed'
    state_dump ps.txt 'ps w'

    # restore doc first, then ONE authoritative manifest over the whole tree
    # (RESTORE.md included — matches the Aug-2026 snapshot ritual); verify
    # reports the true count, so no hand-cited number can drift
    generate_restore_doc "$dest" "$ts"

    ssh_run 'rm -f /tmp/x28-snaplist /tmp/x28-secretslist' >/dev/null 2>&1

    # repo copy must stay small text — binaries slipping through is a bug
    local kb
    kb=$(du -sk "$dest" | awk '{print $1}')
    if [ "${kb:-0}" -gt 8192 ]; then
        echo "capture: REPO COPY TOO BIG (${kb} KB) — an excluded artifact leaked in; aborting"
        return 1
    fi

    mode_manifest "$dest" > "$dest/MANIFEST.sha256"
    mode_verify "$dest" || return 1
    echo "captured: $dest"
    echo "device tarball: /data/proxy/backup/rollback-$ts.tar.gz (secrets; stays on device)"
}

generate_restore_doc() {  # <dest> <ts>
    local dest="$1" ts="$2" size
    size=$(ssh_run "ls -la /data/proxy/backup/rollback-$ts.tar.gz 2>/dev/null | awk '{print \$5}'")
    cat > "$dest/RESTORE.md" <<EOF
# Rollback snapshot $ts — restore procedure

Taken while the X28 was healthy (dashboard serving, health-gate dash slice
GREEN). Nothing was restarted or modified to take it beyond read-only pulls.
Ticket 01 of x28-insights-fairness.

## What exists where

| Copy | Location | Contents |
|---|---|---|
| Device tarball (root-only, 600) | \`/data/proxy/backup/rollback-$ts.tar.gz\` ($(( ${size:-0} / 1024 )) KB) | Everything below **plus the credential-bearing configs** (proxy engine config, tg/samantel confs) |
| Repo copy (secret-free) | \`router/x28/backup/rollback-$ts/\` | All scripts, init units, dashboard files, usage/ledger data, generated-config + firewall/routing/service state dumps, with \`MANIFEST.sha256\` (authoritative count — run \`x28-snapshot.sh verify\` on it) |

Not snapshotted (immutable or regenerated at runtime): the proxy engine
binary and dir, xray / xray.stock / sing-box binaries, the v2raya dir
(binary + DB), geoip/geosite dat files (any variant), the jq binary,
volatile token/cache files, and the adblock lists (regenerate with
\`sh /data/proxy/adblock/adblock-update.sh\`). Secrets never enter the repo.

## Verifying this snapshot

\`\`\`sh
sh router/x28/x28-snapshot.sh verify router/x28/backup/rollback-$ts
\`\`\`

## Restoring (only if a later change breaks the box)

\`\`\`sh
# on the X28, as root — extract over / (files land at their absolute paths)
tar xzf /data/proxy/backup/rollback-$ts.tar.gz -C /

# re-apply the live state captured alongside the files
sh /etc/init.d/x28-dashboard restart   # and any other custom services needed
sh /data/proxy/dns-fix.sh              # DNS mode per tunnel health
sh /data/proxy/harden.sh               # management firewall

# verify
X28_HEALTH_GROUPS=dash sh /data/proxy/x28-health.sh
\`\`\`

The repo copy restores individual files: \`ssh cat < local > remote\` over the
mirrored path (dropbear has no sftp).
EOF
}

case "${1:-}" in
    manifest) shift; mode_manifest "${1:?dir required}" ;;
    verify)   shift; mode_verify "${1:?dir required}" ;;
    capture)  mode_capture ;;
    *) echo "usage: x28-snapshot.sh [manifest <dir>|verify <dir>|capture]" >&2; exit 2 ;;
esac
