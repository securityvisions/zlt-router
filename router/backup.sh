#!/bin/sh
# backup.sh — nightly configuration snapshot of the home network.
#
# Canonical copy lives in this repo (router/backup.sh); it deploys to the
# AX3000T as /root/backup.sh (cron, nightly). Snapshots this router's config,
# the X28 vendor config export + smart-edge configs, into /etc/backups/ and
# keeps BK_KEEP days. Run manually with `sh /root/backup.sh`.

BK_DIR="${BK_DIR:-/etc/backups}"
BK_KEEP="${BK_KEEP:-14}"
# Shared X28 API helpers (session/sha256) — the same module linkstate/reselect
# use. Best-effort: rotation must work even where the helper is absent.
X28_LIB="${X28_LIB:-/root/x28lib.sh}"
[ -f "$X28_LIB" ] && . "$X28_LIB"

# bk_rotate <dir> <keep> — delete oldest snapshots beyond `keep`.
bk_rotate() {
    ls -1 "$1"/backup-*.tar.gz 2>/dev/null | sort | head -n -"$2" | while read -r old; do
        rm -f "$old"
        echo "removed $old"
    done
}

main() {
    local stamp dir
    stamp=$(date +%Y-%m-%d)
    dir="$BK_DIR/$stamp"
    mkdir -p "$dir" "$dir/x28"
    umask 077

    # AX3000T (this router) config.
    for f in /etc/config /etc/tg.conf /etc/routerapp.conf /etc/billing.conf \
             /etc/samantel.conf /etc/crontabs/root /etc/usage-log /etc/balance-log \
             /etc/telemetry; do
        [ -e "$f" ] && cp -a "$f" "$dir/" 2>/dev/null
    done

    # X28 vendor config export (best-effort) + smart-edge configs.
    if command -v x28_session >/dev/null 2>&1; then
        if x28_session; then
            curl -s -m 20 -H 'Content-Type: application/json' \
                -d "{\"cmd\":180,\"method\":\"POST\",\"sessionId\":\"$X28_SID\",\"language\":\"en\"}" \
                "$X28_BASE" 2>/dev/null > "$dir/x28/config_export.json"
        fi
    fi
    # Smart-edge link state (best-effort, via the same HTTP API the watchdog uses).
    if [ -x /root/x28link.sh ]; then
        /root/x28link.sh 2>/dev/null > "$dir/x28/linkstate.txt"
    fi

    # Assemble + rotate.
    tar -czf "$BK_DIR/backup-$stamp.tar.gz" -C "$BK_DIR" "$stamp" 2>/dev/null
    rm -rf "$dir"
    bk_rotate "$BK_DIR" "$BK_KEEP"
    echo "backup written: $BK_DIR/backup-$stamp.tar.gz"
}

case "${1:-}" in
    --rotate) bk_rotate "$2" "${3:-$BK_KEEP}" ;;
    *) main ;;
esac
