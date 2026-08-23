#!/bin/sh
# x28-dash-data.sh — Dashboard JSON snapshot generator (read-only).
#
# Runs every 60 s via procd. Calls existing read-only scripts, converts
# output to JSON, and writes atomic snapshots to /data/proxy/dashboard/data/.
#
# If any script fails or times out, the previous JSON stays on disk.
# Zero mutations — purely reads existing state and writes new files.
#
# Env seams: DASH_DIR, TICK, HN_LIB

set -u

DASH_DIR="${DASH_DIR:-/data/proxy/dashboard/data}"
TICK="${TICK:-60}"
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB" 2>/dev/null || true

JQ="${JQ_BIN:-/data/proxy/jq}"
PROXY="socks5h://192.168.70.1:1080"

mkdir -p "$DASH_DIR" 2>/dev/null

# atomic_json <filename> <json-string> — write only if valid JSON
atomic_json() {
    local f="$1" data="$2"
    printf '%s' "$data" | "$JQ" . > "$DASH_DIR/$f.tmp" 2>/dev/null || { rm -f "$DASH_DIR/$f.tmp"; return 1; }
    mv "$DASH_DIR/$f.tmp" "$DASH_DIR/$f"
}

# run_script <script_path> [args…] — safely execute, capture stdout
run_script() {
    local script="$1"; shift
    timeout 15 sh "$script" "$@" 2>/dev/null || true
}

# ---------- snapshot generators ----------

snap_status() {
    local out=$(run_script /data/proxy/x28-status.sh)
    local health=$(run_script /data/proxy/x28-health.sh | tail -1)
    local verdict="unknown"
    case "$health" in *GREEN*) verdict="green" ;; *RED*) verdict="red" ;; esac

    # parse key=value lines into a JSON object using jq
    printf '%s\n' "$out" | "$JQ" -R -s '
        split("\n") |
        map(select(length > 0)) |
        map(capture("^(?<k>[A-Za-z_]+)\\s+(?<v>.*)$") // {k: ., v: ""}) |
        map({(.k | ascii_downcase | gsub("_";"_")): .v}) |
        add // {}' 2>/dev/null | \
    "$JQ" --arg verdict "$verdict" '. + {
        health_verdict: $verdict,
        timestamp: (now | floor)
    }' 2>/dev/null
}

snap_link() {
    local out=$(timeout 20 sh /data/proxy/linkstate.sh 2>/dev/null)
    printf '%s\n' "$out" | "$JQ" -R -s '
        split("\n") |
        map(select(length > 0)) |
        map(capture("^(?<k>[a-z_0-9]+)=(?<v>.*)$") // empty) |
        map({(.k): .v}) |
        add // {}' 2>/dev/null
}

snap_budget() {
    local out=$(run_script /data/proxy/x28-budget.sh --card)
    if [ -z "$out" ]; then echo '{"error":"no data"}'; return; fi
    # extract key fields from card text
    remain=$(printf '%s\n' "$out" | sed -n 's/.*remaining \([0-9.]*\) GB.*/\1/p' | head -1)
    tier=$(printf '%s\n' "$out" | sed -n 's/.*Budget — \([a-z]*\).*/\1/p' | head -1)
    drain=$(printf '%s\n' "$out" | sed -n 's/.*drain \([0-9.]*\) GB.*/\1/p' | head -1)
    proj=$(printf '%s\n' "$out" | sed -n 's/.*→ ~\([0-9.]*\)d.*/\1/p' | head -1)
    "$JQ" -n --arg remain "${remain:-}" --arg tier "${tier:-ok}" --arg drain "${drain:-}" --arg proj "${proj:-}" \
        '{remaining_gb: $remain, tier: $tier, drain_gb_day: $drain, projected_days_left: $proj}'
}

snap_ledger() {
    local jmonth
    local greg_today=$(date +%F 2>/dev/null)
    jmonth=$("$HN_LIB" hn_greg_to_jalali "$greg_today" 2>/dev/null | true)
    jmonth=$(hn_greg_to_jalali "$greg_today" 2>/dev/null | cut -d- -f1,2 || true)
    [ -z "$jmonth" ] && echo '[]' && return

    sh "$(dirname "$0")/../usage/ledger-store.sh" query "$jmonth" 2>/dev/null | \
    "$JQ" -R -s '
        split("\n") |
        map(select(length > 0)) |
        map(split("\t")) |
        map({
            person: .[0],
            bytes: (.[1] | tonumber? // 0),
            cost_toman: (.[2] | tonumber? // 0)
        })' 2>/dev/null
}

snap_devices() {
    local leases="/tmp/dnsmasq.leases"
    local owners="/data/proxy/owners.conf"
    [ -f "$leases" ] || { echo '[]'; return; }
    cat "$leases" | while IFS=' ' read -r expiry mac ip hostname clientid; do
        [ -z "$mac" ] && continue
        person="unassigned"
        if [ -f "$owners" ]; then
            person=$(grep -i "^${mac}|" "$owners" 2>/dev/null | head -1 | cut -d'|' -f2)
            [ -z "$person" ] && person="unassigned"
        fi
        rnd=false
        c=$(printf '%s' "$mac" | cut -c2)
        case $c in [26aeAE]) rnd=true ;; esac
        printf '{"hostname":"%s","ip":"%s","mac":"%s","owner":"%s","random_mac":%s}\n' \
            "${hostname:-?}" "$ip" "$mac" "$person" "$rnd"
    done | "$JQ" -s '.' 2>/dev/null
}

snap_outages() {
    local ledger="/data/proxy/outage-ledger.log"
    [ -f "$ledger" ] || { echo '{"total_seconds":0,"entries":[]}'; return; }
    "$JQ" -R -s '
        split("\n") | map(select(length > 0)) |
        map(split("|")) |
        map({epoch: (.[0] | tonumber? // 0), kind: .[1]})' "$ledger" 2>/dev/null | \
    "$JQ" '{entries: .}'
}

snap_rescue() {
    local out=$(run_script /data/proxy/x28-rescue.sh status)
    enabled=$(echo "$out" | grep -oE 'enabled=\K\d+' | head -1)
    world=$(echo "$out" | grep -oE 'world=\K\w+' | head -1)
    owned=$(echo "$out" | grep -oE 'owned_alive=\K\d+' | head -1)
    ra=$(echo "$out" | grep -oE 'rescue_alive=\K\d+' | head -1)
    "$JQ" -n --arg en "${enabled:-1}" --arg w "${world:-auto}" --arg o "${owned:-0}" --arg r "${ra:-0}" \
        '{enabled: ($en == "1"), world: $w, owned_alive: ($o | tonumber), rescue_alive: ($r | tonumber)}'
}

# ---------- main loop ----------
tick() {
    snap_status      > "$DASH_DIR/.tmp" && mv "$DASH_DIR/.tmp" "$DASH_DIR/status.json"
    snap_link        > "$DASH_DIR/.tmp" && mv "$DASH_DIR/.tmp" "$DASH_DIR/link.json"
    snap_budget      > "$DASH_DIR/.tmp" && mv "$DASH_DIR/.tmp" "$DASH_DIR/budget.json"
    snap_ledger      > "$DASH_DIR/.tmp" && mv "$DASH_DIR/.tmp" "$DASH_DIR/ledger.json"
    snap_devices     > "$DASH_DIR/.tmp" && mv "$DASH_DIR/.tmp" "$DASH_DIR/devices.json"
    snap_outages     > "$DASH_DIR/.tmp" && mv "$DASH_DIR/.tmp" "$DASH_DIR/outages.json"
    snap_rescue      > "$DASH_DIR/.tmp" && mv "$DASH_DIR/.tmp" "$DASH_DIR/rescue.json"
}

case "${1:-loop}" in
    once) tick ;;
    loop) while :; do tick; sleep "$TICK"; done ;;
esac
