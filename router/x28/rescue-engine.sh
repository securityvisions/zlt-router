#!/bin/sh
# rescue-engine.sh — Deep Rescue Node Ingestion & Aliveness Engine.
#
# Encapsulates:
#   1. Ingestion: Deduplication, base64 parsing, protocol conversion (via rescue-convert.sh).
#   2. Bulk aliveness: Single-query Mihomo aliveness evaluation (O(1) HTTP instead of O(N)).
#   3. Supervision: Hysteresis state machine (promote to rescue after 4 min owned down,
#      demote back after 10 min stable).
#   4. State management: Atomic provider reloading and persistence.
#
# Commands:
#   rescue-engine.sh status [--json]
#   rescue-engine.sh aliveness [group]
#   rescue-engine.sh decide <dead_streak> <alive_streak> <world> <enabled> <rescue_alive>
#   rescue-engine.sh ingest [input_file]
#   rescue-engine.sh supervise
#   rescue-engine.sh switch {on|off|status}

set -u

RESCUE_DIR="${RESCUE_DIR:-/data/proxy/rescue}"
PROVIDER="${PROVIDER:-/data/proxy/mihomo/rescue-pool.yaml}"
CONVERT="${CONVERT:-$(dirname "$0")/rescue-convert.sh}"
RAW="${RESCUE_RAW:-$RESCUE_DIR/raw/collected.txt}"
ENABLED_FILE="$RESCUE_DIR/enabled"
STATE_FILE="$RESCUE_DIR/state"
CTL="${CTL:-http://127.0.0.1:9090}"
JQ="${JQ_BIN:-$(command -v jq || echo /data/proxy/jq)}"
DRYRUN="${DRYRUN:-0}"

mkdir -p "$RESCUE_DIR/raw" 2>/dev/null || true
if [ -d "$RESCUE_DIR" ]; then
    [ -f "$ENABLED_FILE" ] || echo 1 > "$ENABLED_FILE" 2>/dev/null || true
fi

log() {
    echo "$(date '+%F %T') $*" >> "$RESCUE_DIR/rescue.log" 2>/dev/null || true
}

notify() {
    [ -x /data/proxy/tg-notify.sh ] && sh /data/proxy/tg-notify.sh "$1" "$2" >/dev/null 2>&1 || true
}

is_enabled() {
    [ "$(cat "$ENABLED_FILE" 2>/dev/null || echo 1)" = "1" ]
}

api() {
    curl -s -m 6 "$1" 2>/dev/null
}

put_world() {
    local target="$1"
    [ "$DRYRUN" = "1" ] && { log "DRYRUN: would set world=$target"; return 0; }
    curl -s -m 8 -X PUT "$CTL/proxies/world" -d "{\"name\":\"$target\"}" >/dev/null 2>&1 || true
}

# Single bulk query for all proxies to count alive members in a group
bulk_group_alive() {
    local group="${1:-auto}"
    if [ -n "${MOCK_PROXIES_JSON:-}" ]; then
        printf '%s' "$MOCK_PROXIES_JSON"
    else
        api "$CTL/proxies"
    fi | "$JQ" -r --arg g "$group" '
        .proxies as $p |
        ($p[$g].all // []) |
        map(select($p[.].alive == true)) |
        length
    ' 2>/dev/null || echo 0
}

# Pure hysteresis decision logic
# Arguments: dead_streak alive_streak world_mode enabled rescue_alive
re_decide() {
    local dead="$1" alive="$2" world="$3" en="$4" ra="$5"
    case "$dead" in ''|*[!0-9]*) dead=0 ;; esac
    case "$alive" in ''|*[!0-9]*) alive=0 ;; esac
    case "$ra" in ''|*[!0-9]*) ra=0 ;; esac

    [ "$en" = "1" ] || { echo "hold"; return 0; }

    if [ "$world" = "auto" ]; then
        # 4 ticks (4 min) consecutive owned down + at least 1 alive rescue node
        if [ "$dead" -ge 4 ] && [ "$ra" -ge 1 ]; then
            echo "promote"
            return 0
        fi
    elif [ "$world" = "rescue" ]; then
        # 10 ticks (10 min) consecutive owned stable -> revert to owned
        if [ "$alive" -ge 10 ]; then
            echo "demote"
            return 0
        fi
        # If rescue nodes themselves all died, fail back to auto immediately
        if [ "$ra" -eq 0 ]; then
            echo "demote"
            return 0
        fi
    fi

    echo "hold"
}

# Ingest and convert candidate nodes
re_ingest() {
    local src="${1:-$RAW}"
    [ -s "$src" ] || return 0

    local tmp="${PROVIDER}.new.$$"
    if RESCUE_RAW="$src" sh "$CONVERT" > "$tmp" 2>/dev/null && [ -s "$tmp" ]; then
        if ! cmp -s "$tmp" "$PROVIDER" 2>/dev/null; then
            mv -f "$tmp" "$PROVIDER" 2>/dev/null || true
            curl -s -m 10 -X PUT "$CTL/providers/proxies/rescue-pool" >/dev/null 2>&1 || true
            log "Ingested new candidate nodes into rescue pool"
            echo "ingested"
            return 0
        fi
        rm -f "$tmp" 2>/dev/null || true
        echo "unchanged"
        return 2
    fi
    rm -f "$tmp" 2>/dev/null || true
    echo "failed"
    return 1
}

# Supervise loop cycle
re_supervise() {
    is_enabled || { echo "disabled"; return 0; }

    local dead_streak=0 alive_streak=0 world="auto"
    if [ -f "$STATE_FILE" ]; then
        read -r dead_streak alive_streak _ < "$STATE_FILE" 2>/dev/null || true
    fi
    case "$dead_streak" in ''|*[!0-9]*) dead_streak=0 ;; esac
    case "$alive_streak" in ''|*[!0-9]*) alive_streak=0 ;; esac

    world=$(api "$CTL/proxies/world" | "$JQ" -r '.now // "auto"' 2>/dev/null || echo "auto")
    local oa ra decision
    oa=$(bulk_group_alive "auto")
    ra=$(bulk_group_alive "rescue")

    if [ "$oa" -gt 0 ]; then
        alive_streak=$((alive_streak + 1))
        dead_streak=0
    else
        dead_streak=$((dead_streak + 1))
        alive_streak=0
    fi

    echo "$dead_streak $alive_streak 0" > "$STATE_FILE" 2>/dev/null || true

    decision=$(re_decide "$dead_streak" "$alive_streak" "$world" "$(cat "$ENABLED_FILE" 2>/dev/null || echo 1)" "$ra")
    case "$decision" in
        promote)
            put_world "rescue"
            log "PROMOTED world->rescue (owned dead ${dead_streak} ticks, rescue_alive=$ra)"
            notify "🛟 Rescue ACTIVATED" "owned nodes down ≥4 min — traffic moved to tested public nodes ($ra alive). Will revert automatically."
            echo "promoted"
            ;;
        demote)
            put_world "auto"
            log "DEMOTED world->auto (owned alive ${alive_streak} ticks, rescue_alive=$ra)"
            notify "✅ Rescue DEACTIVATED" "owned nodes stable ≥10 min (or rescue drained). Restored to owned VPS."
            echo "demoted"
            ;;
        *)
            echo "hold"
            ;;
    esac
}

# Reporting status
re_status() {
    local fmt="${1:-text}"
    local en world oa ra dead=0 alive=0
    en=$(is_enabled && echo 1 || echo 0)
    world=$(api "$CTL/proxies/world" | "$JQ" -r '.now // "auto"' 2>/dev/null || echo "unknown")
    oa=$(bulk_group_alive "auto")
    ra=$(bulk_group_alive "rescue")

    if [ -f "$STATE_FILE" ]; then
        read -r dead alive _ < "$STATE_FILE" 2>/dev/null || true
    fi

    if [ "$fmt" = "--json" ] || [ "$fmt" = "json" ]; then
        printf '{"enabled":%s,"world":"%s","owned_alive":%s,"rescue_alive":%s,"dead_streak":%s,"alive_streak":%s}\n' \
            "$en" "$world" "$oa" "$ra" "${dead:-0}" "${alive:-0}"
    else
        echo "enabled=$en"
        echo "world=$world"
        echo "owned_alive=$oa"
        echo "rescue_alive=$ra"
        echo "dead_streak=${dead:-0}"
        echo "alive_streak=${alive:-0}"
    fi
}

case "${1:-status}" in
    status)
        shift
        re_status "$@"
        ;;
    aliveness)
        shift
        bulk_group_alive "${1:-auto}"
        ;;
    decide)
        shift
        re_decide "$@"
        ;;
    ingest)
        shift
        re_ingest "$@"
        ;;
    supervise)
        re_supervise
        ;;
    switch)
        shift
        case "${1:-status}" in
            on)  echo 1 > "$ENABLED_FILE"; echo "rescue supervisor enabled" ;;
            off) echo 0 > "$ENABLED_FILE"; echo "rescue supervisor disabled" ;;
            *)   cat "$ENABLED_FILE" 2>/dev/null || echo 1 ;;
        esac
        ;;
    *)
        echo "usage: rescue-engine.sh {status|aliveness|decide|ingest|supervise|switch}"
        exit 1
        ;;
esac
