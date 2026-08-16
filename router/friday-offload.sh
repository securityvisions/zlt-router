#!/bin/sh
# friday-offload.sh — Friday-discount heavy-work offload.
#
# Canonical copy lives in this repo (router/friday-offload.sh); deployed to the
# AX3000T as /root/friday-offload.sh. The Friday window (RATE_FRIDAY_TOMAN,
# default 4,620 T/GB vs 7,700 full) is when heavy downloads should run. This
# script queues heavy jobs (--enqueue), runs the queue when the window opens
# (default/cron), and announces the window (--announce).

HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] && . "$HN_LIB"
QUEUE="${OFFLOAD_QUEUE:-/etc/offload}"
LOG="${OFFLOAD_LOG:-/tmp/offload.log}"

# fo_enqueue <command...> — append a heavy job to the Friday queue.
fo_enqueue() {
    mkdir -p "$QUEUE"
    printf '%s\n' "$*" >> "$QUEUE/jobs"
    echo "queued for Friday: $*"
}

# fo_run <queue_dir> <log> — execute every queued job, in order; a failing job
# stays queued (retry next Friday), successful jobs are removed. Pure-seam.
fo_run() {
    local q="$1" log="$2" tmp line ok
    [ -f "$q/jobs" ] || { echo "offload: queue empty"; return 0; }
    tmp="$q/jobs.tmp"
    : > "$tmp"
    ok=0
    while IFS= read -r line; do
        [ -z "$line" ] && continue
        if sh -c "$line" >> "$log" 2>&1; then
            ok=$((ok + 1))
            echo "$(date '+%F %H:%M') ok: $line" >> "$log"
        else
            echo "$(date '+%F %H:%M') FAIL: $line" >> "$log"
            echo "$line" >> "$tmp"
        fi
    done < "$q/jobs"
    mv "$tmp" "$q/jobs"
    [ -s "$q/jobs" ] || rm -f "$q/jobs"
    echo "offload: ran $ok job(s)"
}

# fo_announce — the window-opening alert.
fo_announce() {
    local days
    days=$(hn_days_until_friday "$(date +%u)")
    [ "$days" = "0" ] || { echo "offload: not Friday ($days days away)"; return 1; }
    [ -x /root/tg.sh ] && /root/tg.sh --text "🎉 Friday discount window is open — heavy downloads should run today (4,620 T/GB)." >/dev/null 2>&1
    echo "announced"
}

main() {
    local days
    days=$(hn_days_until_friday "$(date +%u)")
    if [ "$days" = "0" ]; then
        fo_announce || true
        fo_run "$QUEUE" "$LOG"
    else
        echo "offload: next window in $days day(s)"
    fi
}

case "${1:-}" in
    --enqueue) shift; fo_enqueue "$@" ;;
    --run) fo_run "$2" "${3:-$LOG}" ;;
    --announce) fo_announce ;;
    *) main ;;
esac
