#!/bin/sh
# x28-maint.sh — Maintenance auto-reboot window.
# Nightly-qualified, Sunday-only: inside hour 05 device-local, if uptime
# >= 14 days OR free RAM < 60 MB → warning card → reboot (marker prevents
# double-fire per ISO week even across power blips). Clock-skew guard: the
# decision only fires when device time matches an HTTP Date header fetched
# over the direct path within ±30 min; a skewed clock alerts once/day and
# skips instead of rebooting at the wrong real-world time.
#
# Env seams: MAINT_INTERVAL (loop), MAINT_DRYRUN=1, MAINT_REBOOT_CMD,
# CLOCK_URL (direct-reachable header source).
set -u

HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB"

MAINT_DIR="${MAINT_DIR:-/data/proxy/maint}"
MAINT_INTERVAL="${MAINT_INTERVAL:-600}"
MAINT_DRYRUN="${MAINT_DRYRUN:-0}"
MAINT_REBOOT_CMD="${MAINT_REBOOT_CMD:-reboot}"
CLOCK_URL="${CLOCK_URL:-http://berlin.saymyname.website/}"

mkdir -p "$MAINT_DIR"
MARKER="$MAINT_DIR/window-marker"
SKEW_STAMP="$MAINT_DIR/skew-alert-stamp"

notify() {
    sh /data/proxy/tg-notify.sh "$1" "$2" >/dev/null 2>&1 || true
}

gather() {
    DOW=$(date +%u)
    HR=$(date +%H | sed 's/^0*//'); [ -z "$HR" ] && HR=0
    UPDAYS=$(( $(cut -d. -f1 /proc/uptime 2>/dev/null || echo 0) / 86400 ))
    FREEKB=$(free 2>/dev/null | awk '/Mem:/{print $NF}')
    case "$FREEKB" in ""|*[!0-9]*) FREEKB=999999 ;; esac
    FREEMB=$(( FREEKB / 1024 ))
    WK=$(date +%G-W%V 2>/dev/null)
}

clock_ok() {  # 0 when clock verified or unverifiable-but-proceedable
    hdr=$(curl -sI -m 10 "$CLOCK_URL" 2>/dev/null | sed -n 's/^Date:[[:space:]]*//Ip' | tail -1)
    rem=$(hn_http_date_epoch "$hdr")
    skew=$(hn_clock_skew_ok "$(date +%s)" "$rem")
    if [ "$skew" = "skewed" ]; then
        today=$(date +%Y-%m-%d 2>/dev/null)
        last=$(cat "$SKEW_STAMP" 2>/dev/null)
        logger -t x28-maint "clock skewed vs HTTP Date (local=$(date +%s) remote=${rem:-?}) — skipping window"
        if [ "$today" != "$last" ]; then
            notify "🛠️ Maintenance skipped" "device clock skewed vs network time — auto-reboot postponed until clock is sane"
            echo "$today" > "$SKEW_STAMP" 2>/dev/null
        fi
        return 1
    fi
    # unknown (header unparsable/unreachable): proceed but log
    [ "$skew" = "unknown" ] && logger -t x28-maint "clock check unavailable ($rem) — proceeding"
    return 0
}

maint_tick() {
    gather
    decision=$(hn_maint_should_reboot "$DOW" "$HR" "$UPDAYS" "$FREEMB" "$WK" "$(cat "$MARKER" 2>/dev/null)")
    [ "$decision" = "reboot" ] || return 0

    clock_ok || return 0

    reason="uptime ${UPDAYS}d"
    [ "$FREEMB" -lt 60 ] && reason="free RAM ${FREEMB}MB"
    notify "🛠️ Maintenance reboot now" "qualifier: $reason — restarting to keep the edge fresh (window $WK)"
    echo "$WK" > "$MARKER" 2>/dev/null
    sleep "${MAINT_ARM_DELAY:-15}"
    if [ "$MAINT_DRYRUN" = "1" ]; then
        logger -t x28-maint "DRYRUN: would reboot ($reason)"
        return 0
    fi
    logger -t x28-maint "maintenance reboot executing ($reason)"
    $MAINT_REBOOT_CMD >/dev/null 2>&1 || /sbin/reboot >/dev/null 2>&1 || true
    # if reboot failed, keep looping (marker already set prevents loops this week)
    return 0
}

case "${1:-loop}" in
    once)
        gather
        d=$(hn_maint_should_reboot "$DOW" "$HR" "$UPDAYS" "$FREEMB" "$WK" "$(cat "$MARKER" 2>/dev/null)")
        echo "dow=$DOW hr=$HR uptime_days=$UPDAYS free_mb=$FREEMB week=$WK -> $d"
        ;;
    tick) maint_tick ;;
    loop)
        while :; do
            maint_tick
            sleep "$MAINT_INTERVAL"
        done ;;
    *) echo "usage: x28-maint.sh [loop|tick|once]" >&2; exit 2 ;;
esac
