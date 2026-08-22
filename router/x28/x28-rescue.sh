#!/bin/sh
# x28-rescue.sh — collected-node rescue: admission + world supervision.
#
# Loop (60 s), all engine-driven:
#   1. ADMISSION  — convert raw cache -> candidates; cap residents at 10;
#                   atomically rewrite the provider file; PUT hot-reload.
#   2. SUPERVISE  — read owned-group (auto) aliveness; hysteresis flip of the
#                   `world` selector: promote after 4 min owned-dead (requires
#                   >=1 alive rescue node), demote after 10 min owned-stable.
#   Cards on every promote/demote. Master switch persisted in `enabled`.
#
# One-shots: convert | admit | decide | switch on|off|status | loop
# Env seams: RESCUE_DIR, PROVIDER, TICK, ENABLED_DEFAULT, DRYRUN=1,
#            HEALTH_AUTO_CMD (test seam for owned-alive count).
set -u

HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB"

RESCUE_DIR="${RESCUE_DIR:-/data/proxy/rescue}"
PROVIDER="${PROVIDER:-/data/proxy/mihomo/rescue-pool.yaml}"
CONVERT="${CONVERT:-/data/proxy/rescue-convert.sh}"
RAW="$RESCUE_DIR/raw/collected.txt"
ENABLED_FILE="$RESCUE_DIR/enabled"
STATE="$RESCUE_DIR/state"
TICK="${TICK:-60}"
CTL="${CTL:-http://127.0.0.1:9090}"
JQ="${JQ_BIN:-$(command -v jq || echo /data/proxy/jq)}"
DRYRUN="${DRYRUN:-0}"

mkdir -p "$RESCUE_DIR/raw" 2>/dev/null
[ -f "$ENABLED_FILE" ] || echo 1 > "$ENABLED_FILE"

log() { echo "$(date '+%F %T') $*" >> "$RESCUE_DIR/rescue.log" 2>/dev/null; }
notify() { sh /data/proxy/tg-notify.sh "$1" "$2" >/dev/null 2>&1 || true; }

enabled() { [ "$(cat "$ENABLED_FILE" 2>/dev/null || echo 1)" = "1" ]; }

api() { curl -s -m 6 "$1" 2>/dev/null; }
put_world() {  # put_world <auto|rescue>
    [ "$DRYRUN" = "1" ] && { log "DRYRUN: would set world=$1"; return 0; }
    curl -s -m 8 -X PUT "$CTL/proxies/world" -d "{\"name\":\"$1\"}" >/dev/null 2>&1
}
owned_alive_count() {
    if [ -n "${HEALTH_AUTO_CMD:-}" ]; then sh -c "$HEALTH_AUTO_CMD" 2>/dev/null; return; fi
    local members alive n=0
    members=$(api "$CTL/proxies/auto" | "$JQ" -r '.all[]?' 2>/dev/null)
    for m in $members; do
        alive=$(api "$CTL/proxies/$m" 2>/dev/null | "$JQ" -r '.alive // "false"' 2>/dev/null)
        [ "$alive" = "true" ] && n=$((n + 1))
    done
    echo "$n"
}

# simpler, accurate-enough owned health: count alive among known member list
owned_alive_count() {
    local members alive n=0
    members=$(api "$CTL/proxies/auto" | "$JQ" -r '.all[]?' 2>/dev/null)
    for m in $members; do
        alive=$(api "$CTL/proxies/$m" 2>/dev/null | "$JQ" -r '.alive // "false"' 2>/dev/null)
        [ "$alive" = "true" ] && n=$((n + 1))
    done
    echo "$n"
}

rescue_alive_count() {
    local members alive n=0
    members=$(api "$CTL/proxies/rescue" | "$JQ" -r '.all[]?' 2>/dev/null)
    for m in $members; do
        alive=$(api "$CTL/proxies/$m" 2>/dev/null | "$JQ" -r '.alive // "false"' 2>/dev/null)
        [ "$alive" = "true" ] && n=$((n + 1))
    done
    echo "$n"
}

do_convert() {
    [ -s "$RAW" ] || return 0
    RESCUE_RAW="$RAW" sh "$CONVERT" > "$PROVIDER.new" 2>/dev/null || return 1
    [ -s "$PROVIDER.new" ] || { rm -f "$PROVIDER.new"; return 1; }
    # only swap when content actually changed (avoid needless reloads)
    if ! cmp -s "$PROVIDER.new" "$PROVIDER" 2>/dev/null; then
        mv "$PROVIDER.new" "$PROVIDER"
        return 0   # changed
    fi
    rm -f "$PROVIDER.new"
    return 2       # unchanged
}

reload_provider() {
    curl -s -m 10 -X PUT "$CTL/providers/proxies/rescue-pool" >/dev/null 2>&1 || true
}

admit() {
    enabled || return 0
    do_convert; rc=$?
    [ "$rc" = "0" ] && { reload_provider; log "provider reloaded from raw cache"; }
    return 0
}

supervise() {
    enabled || return 0
    dead_streak=0; alive_streak=0
    [ -f "$STATE" ] && read -r dead_streak alive_streak world_enabled_unused < "$STATE" 2>/dev/null
    case "$dead_streak" in ''|*[!0-9]*) dead_streak=0 ;; esac
    case "$alive_streak" in ''|*[!0-9]*) alive_streak=0 ;; esac

    world=$(api "$CTL/proxies/world" | "$JQ" -r '.now // "auto"' 2>/dev/null)
    oa=$(owned_alive_count)
    ra=$(rescue_alive_count)

    if [ "$oa" -gt 0 ]; then alive_streak=$((alive_streak + 1)); dead_streak=0
    else dead_streak=$((dead_streak + 1)); alive_streak=0; fi

    decision=$(hn_rescue_decide "$dead_streak" "$alive_streak" "$world" "$(cat "$ENABLED_FILE" 2>/dev/null || echo 1)" "$ra")

    case "$decision" in
        promote)
            put_world rescue
            log "PROMOTED world->rescue (owned dead ${dead_streak} ticks, rescue_alive=$ra)"
            notify "🛟 Rescue ACTIVATED" "owned nodes down ≥4 min — traffic moved to tested public nodes ($ra alive). Will revert automatically."
            ;;
        demote)
            put_world auto
            log "DEMOTED world->auto (owned stable ${alive_streak} ticks)"
            notify "🛟 Rescue ended" "owned nodes stable again — back to your own tunnel."
            ;;
    esac
    echo "$dead_streak $alive_streak" > "$STATE"
}

switch_set() {  # switch_set <on|off>
    case "$1" in
        on)  echo 1 > "$ENABLED_FILE"; log "switch: ON"; notify "🛟 Rescue enabled" ;;
        off) echo 0 > "$ENABLED_FILE"
             world=$(api "$CTL/proxies/world" | "$JQ" -r '.now // "auto"')
             [ "$world" = "rescue" ] && { put_world auto; log "switch OFF: forced world->auto"; }
             notify "🛟 Rescue disabled" "admission frozen; world forced to auto."
             ;;
    esac
}

status_line() {
    en=$(cat "$ENABLED_FILE" 2>/dev/null || echo 1)
    world=$(api "$CTL/proxies/world" | "$JQ" -r '.now // "?"' 2>/dev/null)
    ra=$(rescue_alive_count); rt=$(api "$CTL/proxies/rescue" | "$JQ" -r '.all | length' 2>/dev/null || echo "?")
    oa=$(owned_alive_count)
    rawc=0; [ -f "$RAW" ] && rawc=$(wc -l < "$RAW")
    echo "enabled=$en world=$world owned_alive=$oa rescue_alive=$ra/$rt raw_cache=$rawc"
}

case "${1:-loop}" in
    convert) do_convert; exit $? ;;
    admit)   admit ;;
    decide)
        gather_state() { :; }
        world=$(api "$CTL/proxies/world" | "$JQ" -r '.now // "?"')
        echo "status: $(status_line)"
        echo "decide: $(hn_rescue_decide 0 0 "$world" "$(cat "$ENABLED_FILE")" "$(rescue_alive_count)")  (live streaks reset by design here)"
        ;;
    status)  status_line ;;
    switch)  shift; switch_set "${1:-status}" ; [ "${1:-}" = "status" ] && status_line ;;
    tick)    admit; supervise ;;
    loop)
        while :; do
            admit
            supervise
            sleep "$TICK"
        done ;;
    *) echo "usage: x28-rescue.sh [loop|tick|admit|convert|status|decide|switch on|off]" >&2; exit 2 ;;
esac
