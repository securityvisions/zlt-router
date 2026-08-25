#!/bin/sh
# x28-drift.sh — Nightly config backup + drift alert.
# Hourly loop (age-gated to act once per ~20h): hash the critical config
# set, classify against last-known-good via hn_drift_classify, and:
#   CLEAN            → refresh last-run, keep snapshot ring
#   SAME-AS-PENDING  → already alerted for this exact set; stay quiet
#   ALERT            → one Telegram card naming M/A/D files + write pending
# Last-good advances ONLY via `ack` (or first-run baseline), so drift can
# never be silently swallowed by the next snapshot. Bounded snapshot tarball
# ring under /data/proxy/drift/snapshots (keep 14).
#
# Env seams: DRIFT_DIR, DRIFT_FILES, DRIFT_NOTIFY=0 (cards print to stdout),
# DRIFT_INTERVAL, MAINT-style age gate DRIFT_MIN_AGE (default 20h).
set -u

HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$(dirname "$0")/../hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB"

DRIFT_DIR="${DRIFT_DIR:-/data/proxy/drift}"
DRIFT_INTERVAL="${DRIFT_INTERVAL:-3600}"
DRIFT_MIN_AGE="${DRIFT_MIN_AGE:-20}"
DRIFT_NOTIFY="${DRIFT_NOTIFY:-1}"
KEEP_SNAPSHOTS="${DRIFT_KEEP:-14}"

# Critical config set — secrets tracked as hashes only; adblock.conf and
# /tmp regenerated files are deliberately NOT tracked (legit churn).
DEFAULT_FILES="/data/proxy/mihomo/config.yaml /etc/rc.local /etc/hotplug.d/net/30-x28-proxy.sh /data/proxy/tproxy-fixed-enable.sh /data/proxy/tproxy-fixed-disable.sh /data/proxy/dns-fix.sh /data/proxy/harden.sh /data/proxy/owners.conf /data/proxy/x28-bot.sh /data/proxy/operator-watchdog.sh"
DRIFT_FILES="${DRIFT_FILES:-$DEFAULT_FILES}"

mkdir -p "$DRIFT_DIR/snapshots" 2>/dev/null

emit_card() {
    if [ "$DRIFT_NOTIFY" = "1" ]; then
        sh /data/proxy/tg-notify.sh "$1" "$2" >/dev/null 2>&1 || true
    else
        echo "--- CARD: $1 ---"
        printf '%s\n' "$2"
    fi
}

hash_set() {  # "sha path" lines; missing files recorded as "MISSING path"
    for f in $DRIFT_FILES; do
        if [ -f "$f" ]; then
            sha256sum "$f" 2>/dev/null
        else
            echo "MISSING $f"
        fi
    done
}

drift_run() {
    now=$(date +%s)
    lastrun=$(cat "$DRIFT_DIR/last-run" 2>/dev/null || echo 0)
    case "$lastrun" in ""|*[!0-9]*) lastrun=0 ;; esac
    [ $((now - lastrun)) -lt $((DRIFT_MIN_AGE * 3600)) ] && return 0

    cur="$DRIFT_DIR/cur.sha"
    hash_set > "$cur"

    lg="$DRIFT_DIR/last-good.sha"
    pend="$DRIFT_DIR/pending.sha"
    if [ ! -f "$lg" ]; then
        cp "$cur" "$lg"; echo "$now" > "$DRIFT_DIR/last-run"
        logger -t x28-drift "baseline created ($(wc -l < "$lg") files)"
        return 0
    fi

    out=$(hn_drift_classify "$cur" "$lg" "$pend")
    verdict=$(printf '%s\n' "$out" | sed -n 's/^V|//p' | head -1)

    # bounded snapshot ring every run
    stamp=$(date +%Y%m%d-%H%M)
    tar czf "$DRIFT_DIR/snapshots/config-$stamp.tar.gz" -C / \
        $(for f in $DRIFT_FILES; do [ -f "$f" ] && printf '%s ' "${f#/}"; done) 2>/dev/null
    find "$DRIFT_DIR/snapshots" -type f -name 'config-*.tar.gz' -mtime +"$KEEP_SNAPSHOTS" -delete 2>/dev/null

    case "$verdict" in
        CLEAN)
            rm -f "$pend"
            ;;
        SAME-AS-PENDING)
            : ;;  # already alerted this exact set — quiet until ack or new drift
        ALERT)
            changes=$(printf '%s\n' "$out" | grep -E '^[MAD]\|')
            emit_card "🕵️ Config drift detected" "changed files vs last-known-good:
$changes

Review, then acknowledge: x28-drift.sh ack"
            cp "$cur" "$pend"
            ;;
    esac
    echo "$now" > "$DRIFT_DIR/last-run"
    return 0
}

drift_ack() {
    cur="$DRIFT_DIR/cur.sha"
    hash_set > "$cur"
    cp "$cur" "$DRIFT_DIR/last-good.sha"
    rm -f "$DRIFT_DIR/pending.sha"
    emit_card "🧷 Drift acknowledged" "last-known-good advanced to current state ($(wc -l < "$cur") files)"
}

case "${1:-loop}" in
    run|tick)  drift_run ;;
    status)
        echo "tracked: $(echo $DRIFT_FILES | wc -w) files"
        [ -f "$DRIFT_DIR/pending.sha" ] && echo "pending: ALERTED, unacknowledged" || echo "pending: none"
        echo "last-run: $(cat "$DRIFT_DIR/last-run" 2>/dev/null || echo never)"
        ;;
    ack)       drift_ack ;;
    loop)
        while :; do
            drift_run
            sleep "$DRIFT_INTERVAL"
        done ;;
    *) echo "usage: x28-drift.sh [loop|run|status|ack]" >&2; exit 2 ;;
esac
