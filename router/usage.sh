#!/bin/sh
# Per-device usage from nlbwmon
# Usage:
#   usage.sh --today            -> today's usage: name|mac|bytes
#   usage.sh --snapshot         -> store daily diff into monthly log (idempotent)
#   usage.sh --month [YYYY-MM]  -> month usage: name|mac|bytes
#   usage.sh --raw              -> debug: current cumulative rows
USAGE_DIR="${USAGE_DIR:-/etc/usage-log}"
LAST_FILE="$USAGE_DIR/last"
NAMES_CACHE="$USAGE_DIR/names"
USER_NAMES="$USAGE_DIR/user-names"
NLBW_BIN="${NLBW_BIN:-/usr/sbin/nlbw}"
DHCP_LEASES="${DHCP_LEASES:-/tmp/dhcp.leases}"
BILLING_CONF="${BILLING_CONF:-/etc/billing.conf}"

mkdir -p "$USAGE_DIR" 2>/dev/null

# current cumulative per-mac total bytes (rx+tx) as tsv: mac<TAB>bytes
usage_rows() {
    "$NLBW_BIN" -c json -g mac 2>/dev/null | jq -r '.data[] | [.[0], (.[2]+.[4])] | @tsv'
}

# remember a mac->name mapping (persistent; survives lease expiry)
remember_name() {
    local mac="$1" name="$2"
    [ -z "$mac" ] && return 0
    [ -z "$name" ] && return 0
    grep -q "^$mac $name$" "$NAMES_CACHE" 2>/dev/null && return 0
    grep -v "^$mac " "$NAMES_CACHE" 2>/dev/null > "$NAMES_CACHE.tmp" || true
    mv "$NAMES_CACHE.tmp" "$NAMES_CACHE" 2>/dev/null
    echo "$mac $name" >> "$NAMES_CACHE"
}

# name for a mac: user-set name wins, then live DHCP lease, then auto cache
dev_name() {
    local mac="$1" name
    name=$(awk -v m="$mac" '$1==m {print $2; exit}' "$USER_NAMES" 2>/dev/null)
    [ -n "$name" ] && { echo "$name"; return 0; }
    name=$(awk -v m="$mac" 'tolower($2)==tolower(m) {print $4; exit}' "$DHCP_LEASES" 2>/dev/null)
    [ -n "$name" ] && { echo "$name"; return 0; }
    awk -v m="$mac" '$1==m {print $2; exit}' "$NAMES_CACHE" 2>/dev/null
}

# every known device mac (nlbw + leases + caches), router macs excluded
known_macs() {
    {
        usage_rows | cut -f1
        awk '{print $2}' "$DHCP_LEASES" 2>/dev/null
        awk '{print $1}' "$NAMES_CACHE" 2>/dev/null
        awk '{print $1}' "$USER_NAMES" 2>/dev/null
    } | tr 'A-F' 'a-f' | grep -E '^([0-9a-f]{2}:){5}[0-9a-f]{2}$' | sort -u | while read -r mac; do
        is_router_mac "$mac" || echo "$mac"
    done
}

# full list: mac|name|source(lease/user/auto/unknown)|bytes
list_names() {
    local nbwmap mac name src bytes u l a
    nbwmap=$(usage_rows)
    known_macs | while read -r mac; do
        name=""; src="unknown"
        u=$(awk -v m="$mac" '$1==m{print $2; exit}' "$USER_NAMES" 2>/dev/null)
        if [ -n "$u" ]; then
            name=$u; src=user
        else
            l=$(awk -v m="$mac" 'tolower($2)==m{print $4; exit}' "$DHCP_LEASES" 2>/dev/null)
            if [ -n "$l" ]; then
                name=$l; src=lease
            else
                a=$(awk -v m="$mac" '$1==m{print $2; exit}' "$NAMES_CACHE" 2>/dev/null)
                [ -n "$a" ] && { name=$a; src=auto; }
            fi
        fi
        [ -z "$name" ] && name="Unknown-$(printf '%s' "$mac" | cut -c1-8)"
        bytes=$(echo "$nbwmap" | awk -v m="$mac" -F"$(printf '\t')" '$1==m{print $2; exit}')
        [ -z "$bytes" ] && bytes=0
        echo "$mac|$name|$src|$bytes"
    done
}

# resolve a full mac or a unique prefix to a full colon-separated lowercase mac
resolve_mac() {
    local arg="$1" macs matches
    [ -z "$arg" ] && return 1
    arg=$(echo "$arg" | tr 'A-F' 'a-f' | tr -d ' :.-')
    macs=$(known_macs | tr -d ':')
    matches=$(echo "$macs" | grep "^$arg" || true)
    case "$(echo "$matches" | grep -c .)" in
        1)
            echo "$matches" | sed 's/^\(..\)\(..\)\(..\)\(..\)\(..\)\(..\)$/\1:\2:\3:\4:\5:\6/'
            return 0
            ;;
    esac
    return 1
}

is_router_mac() {
    local mac="$1"
    [ "$mac" = "00:00:00:00:00:00" ] && return 0
    ip link show 2>/dev/null | grep -q "link/ether $mac"
}

# current cumulative per device: name|mac|bytes (router macs excluded)
device_usage() {
    usage_rows | while IFS="$(printf '\t')" read -r mac bytes; do
        [ -z "$mac" ] && continue
        is_router_mac "$mac" && continue
        # learn a live lease name into the auto cache (user names always win in dev_name)
        lname=$(awk -v m="$mac" 'tolower($2)==tolower(m) {print $4; exit}' "$DHCP_LEASES" 2>/dev/null)
        [ -n "$lname" ] && remember_name "$mac" "$lname"
        name=$(dev_name "$mac")
        [ -z "$name" ] && name="Unknown-$(printf '%s' "$mac" | cut -c1-8)"
        echo "$name|$mac|$bytes"
    done
}

# diff usage vs last snapshot: name|mac|bytes (today's usage)
today_usage() {
    device_usage | while IFS='|' read -r name mac bytes; do
        prev=$(awk -v m="$mac" '$1==m{print $2; exit}' "$LAST_FILE" 2>/dev/null)
        prev=${prev:-0}
        diff=$((bytes - prev))
        [ "$diff" -lt 0 ] && diff=$bytes
        [ "$diff" -gt 0 ] && echo "$name|$mac|$diff"
    done
}

# idempotent daily snapshot into monthly log
snapshot() {
    local today ym
    today=$(date +%Y-%m-%d)
    ym=$(date +%Y-%m)

    if [ ! -f "$LAST_FILE" ]; then
        device_usage | awk -F'|' '{print $2, $3}' > "$LAST_FILE"
        return 0
    fi

    TMP=$(mktemp)
    today_usage | while IFS='|' read -r name mac bytes; do
        echo "$today|$mac|$bytes"
    done > "$TMP"

    if [ -s "$TMP" ]; then
        if [ -f "$USAGE_DIR/$ym.log" ]; then
            grep -v "^$today|" "$USAGE_DIR/$ym.log" > "$USAGE_DIR/$ym.tmp" 2>/dev/null || true
            mv "$USAGE_DIR/$ym.tmp" "$USAGE_DIR/$ym.log"
        fi
        cat "$TMP" >> "$USAGE_DIR/$ym.log"
    fi
    rm -f "$TMP"

    device_usage | awk -F'|' '{print $2, $3}' > "$LAST_FILE"
}

# summed month usage: name|mac|bytes
month_usage() {
    local ym="${1:-$(date +%Y-%m)}"
    [ -f "$USAGE_DIR/$ym.log" ] || return 1
    awk -F'|' '$3+0>0 {sum[$2]+=$3} END {for (m in sum) print m, sum[m]}' "$USAGE_DIR/$ym.log" | while read -r mac bytes; do
        name=$(dev_name "$mac")
        [ -z "$name" ] && name="Unknown-$(printf '%s' "$mac" | cut -c1-8)"
        echo "$name|$mac|$bytes"
    done
}

case "$1" in
    --today)    today_usage ;;
    --snapshot) snapshot ;;
    --month)    month_usage "${2:-$(date +%Y-%m)}" ;;
    --raw)      device_usage ;;
    --name)
        n=$(dev_name "$2")
        [ -z "$n" ] && n="Unknown-$(printf '%s' "$2" | cut -c1-8)"
        echo "$n"
        ;;
    --names)    list_names ;;
    --resolve)  resolve_mac "$2" ;;
    --report)
        friday=$(awk -F= '/^LAST_FRIDAY=/{print $2}' "$BILLING_CONF" 2>/dev/null)
        msg=$(/root/billing.sh --today "${friday:-no}")
        [ -n "$msg" ] && /root/tg.sh "$msg"
        ;;
    *)          echo "usage: $0 {--today|--snapshot|--month [YYYY-MM]|--raw|--report}" >&2 ;;
esac
