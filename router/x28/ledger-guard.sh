#!/bin/sh
# ledger-guard.sh — retention guard for the Ledger history (owners-d/).
#
# The household Ledger is append-forever by design; nothing prunes it. This
# guard is the tripwire: it records high-water marks (oldest day, day count)
# and alerts via Telegram when the history shrinks from either end (flash
# failure, bad rm, botched restore). After alerting once it records the new
# reality, so one shrinkage event alerts exactly once.
#
# Modes:
#   run   — check at most once per calendar month (marker)
#   check — check now, no marker (manual / tests)
#
# Env seams for tests: USAGE_DIR, MONTH, ALERT_CMD.
# Canonical copy: router/x28/ledger-guard.sh — deploys to /data/proxy/ledger-guard.sh.

USAGE_DIR="${USAGE_DIR:-/data/proxy/usage}"
OD="$USAGE_DIR/owners-d"
state="$USAGE_DIR/.ledger-span"

oldest_day() { ls -1 "$OD" 2>/dev/null | grep -E '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' | sort | head -1; }
newest_day() { ls -1 "$OD" 2>/dev/null | grep -E '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$' | sort | tail -1; }
day_count() { ls -1 "$OD" 2>/dev/null | grep -cE '^20[0-9]{2}-[0-9]{2}-[0-9]{2}$'; }
# the other permanent stores: monthly rollups + frozen Ledger pages
store_count() { ls -1 "$USAGE_DIR/$1" 2>/dev/null | grep -cE '^20|^J-'; }

send_alert() {
    if [ -n "${ALERT_CMD:-}" ]; then
        sh -c "$ALERT_CMD" ledger-guard "$1"
    else
        sh /data/proxy/tg-notify.sh "⚠️ Ledger retention" "$1" >/dev/null 2>&1 || true
    fi
}

do_check() {
    cur_old=$(oldest_day)
    [ -n "$cur_old" ] || return 0
    cur_new=$(newest_day)
    cur_n=$(day_count)
    cur_r=$(store_count rollups)
    cur_l=$(store_count ledger)
    rec_old=$(cut -d'|' -f1 "$state" 2>/dev/null)
    rec_n=$(cut -d'|' -f2 "$state" 2>/dev/null)
    rec_new=$(cut -d'|' -f3 "$state" 2>/dev/null)
    rec_r=$(cut -d'|' -f4 "$state" 2>/dev/null)
    rec_l=$(cut -d'|' -f5 "$state" 2>/dev/null)
    msg=""
    if [ -n "$rec_old" ] && [ "$cur_old" \> "$rec_old" ] 2>/dev/null; then
        msg="oldest day moved $rec_old → $cur_old"
    fi
    if [ -n "$rec_new" ] && [ "$cur_new" \< "$rec_new" ] 2>/dev/null; then
        [ -n "$msg" ] && msg="$msg; "
        msg="${msg}newest day moved back $rec_new → $cur_new"
    fi
    if [ -n "$rec_n" ] && [ "$cur_n" -lt "$rec_n" ] 2>/dev/null; then
        [ -n "$msg" ] && msg="$msg; "
        msg="${msg}day count $rec_n → $cur_n"
    fi
    if [ -n "$rec_r" ] && [ "$cur_r" -lt "$rec_r" ] 2>/dev/null; then
        [ -n "$msg" ] && msg="$msg; "
        msg="${msg}rollup months $rec_r → $cur_r"
    fi
    if [ -n "$rec_l" ] && [ "$cur_l" -lt "$rec_l" ] 2>/dev/null; then
        [ -n "$msg" ] && msg="$msg; "
        msg="${msg}frozen ledger pages $rec_l → $cur_l"
    fi
    if [ -n "$msg" ]; then
        send_alert "Ledger history shrank: $msg"
    fi
    # record current reality (growth + post-alert baseline)
    printf '%s|%s|%s|%s|%s\n' "$cur_old" "$cur_n" "$cur_new" "$cur_r" "$cur_l" > "$state" 2>/dev/null
    return 0
}

case "${1:-run}" in
    check) do_check ;;
    run)
        m="${MONTH:-$(date +%Y-%m)}"
        [ "$(cat "$state.month" 2>/dev/null)" = "$m" ] && exit 0
        do_check
        echo "$m" > "$state.month" 2>/dev/null
        ;;
    *)
        echo "usage: ledger-guard.sh [run|check]" >&2; exit 2 ;;
esac
