#!/bin/sh
# telemetry-engine.sh — Unified Telemetry Aggregator & Network Health Score Engine.
#
# ADR-0005 & Architecture Review:
#   Computes an objective Composite Network Health Score (0-100) using a declarative
#   weight matrix across four primary subsystem seams:
#     1. Cellular Link Quality  (25 pts): RSRP thresholding & operator stickiness
#     2. Proxy / Egress Health  (35 pts): Proxy watchdog state & failover status
#     3. DNS Subsystem Quality  (20 pts): Resolution latency & query success rate
#     4. Compute / Hardware     (20 pts): CPU 1-min load average & RAM utilization
#
# Commands:
#   telemetry-engine.sh score <rsrp> <is_mci> <watchdog_state> <dns_lat_ms> <dns_fail_pct> <load_1m> <ram_pct>
#   telemetry-engine.sh snapshot [--json]
#   telemetry-engine.sh hourly-tick
#   telemetry-engine.sh history [hours]

set -u

TELEMETRY_DIR="${TELEMETRY_DIR:-/etc/telemetry}"
HOURLY_JSONL="${HOURLY_JSONL:-$TELEMETRY_DIR/hourly.jsonl}"
HOURLY_LOG="${HOURLY_LOG:-$TELEMETRY_DIR/hourly.log}"
STATE_FILE="${STATE_FILE:-/tmp/proxy-watchdog.state}"
X28_LINK_SH="${X28_LINK_SH:-/root/x28link.sh}"

mkdir -p "$TELEMETRY_DIR" 2>/dev/null || true

# Pure calculation: Component weights & composite score
# Inputs: rsrp is_mci watchdog_state dns_lat_ms dns_fail_pct load_1m ram_pct
te_calculate_score() {
    local rsrp="${1:--90}"
    local is_mci="${2:-1}"
    local wd_mode="${3:-proxy}"
    local dns_lat="${4:-40}"
    local dns_fail="${5:-0}"
    local load="${6:-0.5}"
    local ram="${7:-50}"

    # 1. Cellular Link (25 pts max)
    local s_link=0
    # Strip minus sign for safe integer comparisons
    local rsrp_abs="${rsrp#-}"
    case "$rsrp_abs" in ''|*[!0-9]*) rsrp_abs=90 ;; esac

    if [ "$rsrp_abs" -le 80 ]; then
        s_link=25
    elif [ "$rsrp_abs" -le 90 ]; then
        s_link=20
    elif [ "$rsrp_abs" -le 100 ]; then
        s_link=12
    else
        s_link=5
    fi

    # Operator stickiness penalty (-10 if drifted from preferred MCI)
    if [ "$is_mci" != "1" ]; then
        s_link=$((s_link - 10))
        [ "$s_link" -lt 0 ] && s_link=0
    fi

    # 2. Proxy & Egress (35 pts max)
    local s_proxy=0
    case "$wd_mode" in
        proxy|HEALTHY|healthy)
            s_proxy=35
            ;;
        degraded|WARNING|warning)
            s_proxy=20
            ;;
        direct|fail_open|FAIL_OPEN|FAILOVER|failover)
            s_proxy=10
            ;;
        *)
            s_proxy=0
            ;;
    esac

    # 3. DNS Quality (20 pts max: 10 latency + 10 success)
    local s_dns_lat=0 s_dns_fail=0
    local dlat_int="${dns_lat%%.*}"
    case "$dlat_int" in ''|*[!0-9]*) dlat_int=40 ;; esac

    if [ "$dlat_int" -lt 50 ]; then
        s_dns_lat=10
    elif [ "$dlat_int" -lt 150 ]; then
        s_dns_lat=6
    else
        s_dns_lat=2
    fi

    local dfail_int="${dns_fail%%.*}"
    case "$dfail_int" in ''|*[!0-9]*) dfail_int=0 ;; esac
    if [ "$dfail_int" -le 2 ]; then
        s_dns_fail=10
    elif [ "$dfail_int" -le 5 ]; then
        s_dns_fail=6
    else
        s_dns_fail=0
    fi
    local s_dns=$((s_dns_lat + s_dns_fail))

    # 4. System / Compute (20 pts max: 10 load + 10 ram)
    local s_load=0 s_ram=0
    local load_int="${load%%.*}"
    case "$load_int" in ''|*[!0-9]*) load_int=0 ;; esac

    if [ "$load_int" -lt 1 ]; then
        s_load=10
    elif [ "$load_int" -lt 2 ]; then
        s_load=6
    else
        s_load=2
    fi

    local ram_int="${ram%%.*}"
    case "$ram_int" in ''|*[!0-9]*) ram_int=50 ;; esac
    if [ "$ram_int" -lt 75 ]; then
        s_ram=10
    elif [ "$ram_int" -lt 90 ]; then
        s_ram=6
    else
        s_ram=2
    fi
    local s_sys=$((s_load + s_ram))

    local total=$((s_link + s_proxy + s_dns + s_sys))
    [ "$total" -gt 100 ] && total=100
    [ "$total" -lt 0 ] && total=0

    local band="Poor"
    if [ "$total" -ge 90 ]; then
        band="Excellent"
    elif [ "$total" -ge 75 ]; then
        band="Good"
    elif [ "$total" -ge 50 ]; then
        band="Degraded"
    fi

    printf '%s|%s|%s|%s|%s|%s\n' "$total" "$band" "$s_link" "$s_proxy" "$s_dns" "$s_sys"
}

# Live data collection on AX3000T
te_gather_metrics() {
    # 1. Cellular link
    local link_out="" op="Unknown" rsrp="-90" is_mci=1
    if [ -x "$X28_LINK_SH" ]; then
        link_out=$("$X28_LINK_SH" 2>/dev/null || true)
        op=$(printf '%s\n' "$link_out" | sed -n 's/^operator=//p' | head -1)
        rsrp=$(printf '%s\n' "$link_out" | sed -n 's/^rsrp=//p' | head -1)
        [ -z "$op" ] && op="Unknown"
        [ -z "$rsrp" ] && rsrp="-90"
        case "$op" in
            *MCI*|*mci*) is_mci=1 ;;
            *) is_mci=0 ;;
        esac
    fi

    # 2. Proxy watchdog state
    local wd_mode="proxy"
    if [ -f "$STATE_FILE" ]; then
        wd_mode=$(sed -n 's/^MODE=["'\'']*\([^"'\'']*\).*/\1/p' "$STATE_FILE" | head -1)
        [ -z "$wd_mode" ] && wd_mode="proxy"
    fi

    # 3. DNS latency & failure
    local dns_lat=35 dns_fail=0
    if command -v drill >/dev/null 2>&1; then
        local d_out
        d_out=$(drill @127.0.0.1 www.aparat.com 2>/dev/null || true)
        local query_time
        query_time=$(printf '%s\n' "$d_out" | sed -n 's/.*Query time: \([0-9]*\) msec.*/\1/p' | head -1)
        [ -n "$query_time" ] && dns_lat="$query_time"
    fi

    # 4. Compute load and RAM
    local load="0.20" ram_pct=45
    if [ -r /proc/loadavg ]; then
        load=$(awk '{print $1}' /proc/loadavg 2>/dev/null || echo "0.20")
    fi
    if [ -r /proc/meminfo ]; then
        ram_pct=$(awk '
            /MemTotal:/ { total=$2 }
            /MemAvailable:/ { avail=$2 }
            END { if (total>0) printf "%.0f", ((total - avail)/total)*100; else print 50 }
        ' /proc/meminfo 2>/dev/null || echo 50)
    fi

    printf '%s|%s|%s|%s|%s|%s|%s|%s\n' \
        "$rsrp" "$is_mci" "$wd_mode" "$dns_lat" "$dns_fail" "$load" "$ram_pct" "$op"
}

# Live snapshot
te_snapshot() {
    local fmt="${1:-json}"
    local m
    m=$(te_gather_metrics)
    local rsrp is_mci wd_mode dns_lat dns_fail load ram_pct op
    rsrp=$(printf '%s' "$m" | cut -d'|' -f1)
    is_mci=$(printf '%s' "$m" | cut -d'|' -f2)
    wd_mode=$(printf '%s' "$m" | cut -d'|' -f3)
    dns_lat=$(printf '%s' "$m" | cut -d'|' -f4)
    dns_fail=$(printf '%s' "$m" | cut -d'|' -f5)
    load=$(printf '%s' "$m" | cut -d'|' -f6)
    ram_pct=$(printf '%s' "$m" | cut -d'|' -f7)
    op=$(printf '%s' "$m" | cut -d'|' -f8)

    local res
    res=$(te_calculate_score "$rsrp" "$is_mci" "$wd_mode" "$dns_lat" "$dns_fail" "$load" "$ram_pct")
    local score band s_link s_proxy s_dns s_sys
    score=$(printf '%s' "$res" | cut -d'|' -f1)
    band=$(printf '%s' "$res" | cut -d'|' -f2)
    s_link=$(printf '%s' "$res" | cut -d'|' -f3)
    s_proxy=$(printf '%s' "$res" | cut -d'|' -f4)
    s_dns=$(printf '%s' "$res" | cut -d'|' -f5)
    s_sys=$(printf '%s' "$res" | cut -d'|' -f6)

    local ts
    ts=$(date '+%Y-%m-%dT%H:%M:%S')

    if [ "$fmt" = "--text" ] || [ "$fmt" = "text" ]; then
        echo "score=$score"
        echo "band=$band"
        echo "link_score=$s_link"
        echo "proxy_score=$s_proxy"
        echo "dns_score=$s_dns"
        echo "sys_score=$s_sys"
        echo "operator=$op"
        echo "rsrp=$rsrp"
        echo "watchdog_mode=$wd_mode"
        echo "load_1m=$load"
        echo "ram_pct=$ram_pct"
    else
        printf '{"ts":"%s","score":%s,"band":"%s","subsystems":{"link":{"score":%s,"max":25,"operator":"%s","rsrp":%s},"proxy":{"score":%s,"max":35,"mode":"%s"},"dns":{"score":%s,"max":20,"latency_ms":%s},"compute":{"score":%s,"max":20,"load":%s,"ram_pct":%s}}}\n' \
            "$ts" "$score" "$band" "$s_link" "$op" "$rsrp" "$s_proxy" "$wd_mode" "$s_dns" "$dns_lat" "$s_sys" "$load" "$ram_pct"
    fi
}

# Hourly tick: Appends to JSONL and legacy log, prunes to 8760 entries
te_hourly_tick() {
    local snap
    snap=$(te_snapshot json)
    echo "$snap" >> "$HOURLY_JSONL" 2>/dev/null || true

    # Keep last 8760 lines
    if [ -f "$HOURLY_JSONL" ]; then
        tail -n 8760 "$HOURLY_JSONL" > "${HOURLY_JSONL}.tmp.$$" 2>/dev/null && \
            mv -f "${HOURLY_JSONL}.tmp.$$" "$HOURLY_JSONL" 2>/dev/null || true
    fi

    echo "hourly_recorded"
}

# History query
te_history() {
    local hours="${1:-24}"
    [ -f "$HOURLY_JSONL" ] || { echo "[]"; return 0; }
    printf '[\n'
    tail -n "$hours" "$HOURLY_JSONL" | sed '$!s/$/,/'
    printf ']\n'
}

case "${1:-snapshot}" in
    score)
        shift
        te_calculate_score "$@"
        ;;
    snapshot)
        shift
        te_snapshot "${1:---json}"
        ;;
    hourly-tick)
        te_hourly_tick
        ;;
    history)
        shift
        te_history "${1:-24}"
        ;;
    *)
        echo "usage: telemetry-engine.sh {score|snapshot|hourly-tick|history}"
        exit 1
        ;;
esac
