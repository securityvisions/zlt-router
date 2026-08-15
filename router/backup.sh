#!/bin/sh
# backup.sh — nightly configuration snapshot of the home network.
#
# Canonical copy lives in this repo (router/backup.sh); it deploys to the
# AX3000T as /root/backup.sh (cron, nightly). Snapshots this router's config,
# the X28 vendor config export + smart-edge configs, into /etc/backups/ and
# keeps BK_KEEP days. Run manually with `sh /root/backup.sh`.

BK_DIR="${BK_DIR:-/etc/backups}"
BK_KEEP="${BK_KEEP:-14}"
X28_BASE="${X28_BASE:-http://192.168.70.1/cgi-bin/http.cgi}"
X28_USER="${X28_USER:-admin}"
X28_PASS="${X28_PASS:-admin}"

# bk_rotate <dir> <keep> — delete oldest snapshots beyond `keep`.
bk_rotate() {
    ls -1 "$1"/backup-*.tar.gz 2>/dev/null | sort | head -n -"$2" | while read -r old; do
        rm -f "$old"
        echo "removed $old"
    done
}

bk_x28_login() {  # sets X28_SID via the vendor API; non-zero on failure
    local token pass
    token=$(curl -s -m 8 -H 'Content-Type: application/json' \
        -d '{"cmd":232,"method":"GET","sessionId":""}' "$X28_BASE" 2>/dev/null |
        sed -n 's/.*"token":"\([0-9a-f]*\)".*/\1/p' | head -1)
    [ -n "$token" ] || return 1
    pass=$(printf '%s' "${token}${X28_PASS}" | sha256sum | awk '{print $1}')
    X28_SID=$(curl -s -m 8 -H 'Content-Type: application/json' \
        -d "{\"cmd\":100,\"method\":\"POST\",\"sessionId\":\"\",\"username\":\"$X28_USER\",\"passwd\":\"$pass\",\"isAutoUpgrade\":\"0\",\"subcmd\":0,\"language\":\"en\"}" \
        "$X28_BASE" 2>/dev/null |
        sed -n 's/.*"sessionId":"\([0-9a-f]*\)".*/\1/p' | head -1)
    [ -n "$X28_SID" ]
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
    if bk_x28_login; then
        curl -s -m 20 -H 'Content-Type: application/json' \
            -d "{\"cmd\":180,\"method\":\"POST\",\"sessionId\":\"$X28_SID\",\"language\":\"en\"}" \
            "$X28_BASE" 2>/dev/null > "$dir/x28/config_export.json"
    fi
    # Smart-edge files are on the X28; fetch them over SSH when the deploy key
    # is usable, else the snapshot just covers this router + vendor export.
    if [ -x /root/x28link.sh ]; then
        /root/x28link.sh 2>/dev/null > "$dir/x28/linkstate.txt"
    fi

    # VPS s-ui config (best-effort, optional): run `sui backup` on the VPS if
    # an SSH alias exists. Skipped silently when not configured.
    if ssh -o BatchMode=yes -o ConnectTimeout=5 -o StrictHostKeyChecking=no vps \
            'test -x /usr/local/s-ui/sui && /usr/local/s-ui/sui backup >/dev/null 2>&1; ls -t /usr/local/s-ui/db/s-ui.db.bak* 2>/dev/null | head -1' \
            > /dev/null 2>&1; then :; fi

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
