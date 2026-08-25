#!/bin/sh
# x28-budget.sh — Data Budget Guardian (warn/urgent/exhausted).
# Reads the Samantel balance report cache, forecasts exhaustion, and
# emits a Card. --check mode is cooldown-gated and sends via tg-notify;
# --report/--card just prints the Card (for /budget).
# Env overrides for tests:
#   BALANCE_REPORT, BUDGET_STATE, HN_LIB, DATE_CMD (for deterministic dates)
set -eu

BALANCE_REPORT="${BALANCE_REPORT:-/tmp/balance_report}"
BUDGET_STATE="${BUDGET_STATE:-/tmp/budget-cooldown.state}"
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$(dirname "$0")/../hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB"

DATE_CMD="${DATE_CMD:-date}"

# Parse drain GB/day from the drain string like "~3.5 GB/day → ~41d left"
_parse_drain() {
    printf '%s' "$1" | grep -o '[0-9][0-9.]*[[:space:]]*GB\/day' 2>/dev/null | grep -o '[0-9][0-9.]*' | head -1
}

budget_card() {
    local fields drain_str drain_gb remain quota pct expires days tier proj_days exhaust_greg exhaust_jal
    fields=$(hn_balance_fields "$BALANCE_REPORT" 2>/dev/null || echo "available=0")
    remain=$(printf '%s\n' "$fields" | sed -n 's/^remain=//p' | head -1)
    quota=$(printf '%s\n' "$fields" | sed -n 's/^quota=//p' | head -1)
    pct=$(printf '%s\n' "$fields" | sed -n 's/^pct=//p' | head -1)
    expires=$(printf '%s\n' "$fields" | sed -n 's/^expires=//p' | head -1)
    days=$(printf '%s\n' "$fields" | sed -n 's/^days=//p' | head -1)
    drain_str=$(printf '%s\n' "$fields" | sed -n 's/^drain=//p' | head -1)
    drain_gb=$(_parse_drain "$drain_str")
    [ -z "$drain_gb" ] && drain_gb=""

    # available check
    avail=$(printf '%s\n' "$fields" | sed -n 's/^available=//p' | head -1)
    if [ "$avail" != "1" ] || [ -z "$remain" ]; then
        echo "💰 Budget — no data"
        echo "──────────────"
        echo "balance report not available yet"
        return 0
    fi

    # projected days = remain / drain_gb
    if [ -n "$drain_gb" ] && [ "$drain_gb" != "0" ]; then
        proj_days=$(awk -v r="$remain" -v d="$drain_gb" 'BEGIN{printf "%.1f", r/d}')
        proj_int=$(printf '%s' "$proj_days" | cut -d. -f1)
        [ -z "$proj_int" ] && proj_int=0
        # exhaustion date = today + proj_int days
        exhaust_greg=$($DATE_CMD -d "+${proj_int} days" +%F 2>/dev/null || $DATE_CMD +%F)
        exhaust_jal=$(hn_greg_to_jalali "$exhaust_greg" 2>/dev/null || echo "")
    else
        proj_days=""
        exhaust_greg=""
        exhaust_jal=""
    fi

    tier=$(hn_budget_tier "$remain" "$days" "$proj_days" 2>/dev/null || echo "ok")

    # projected month-end cost (Toman): extrapolate month-to-date usage at full rate
    BUDGET_USAGE_DIR="${BUDGET_USAGE_DIR:-/data/proxy/usage}"
    RATE_FULL="${RATE_FULL:-7700}"
    [ -r "$BUDGET_USAGE_DIR/billing.conf" ] && . "$BUDGET_USAGE_DIR/billing.conf" 2>/dev/null || true
    proj_cost=""
    b_month=$($DATE_CMD +%Y-%m 2>/dev/null || true)
    b_days_in=$($DATE_CMD -d "$b_month-01 +1 month -1 day" +%d 2>/dev/null | tr -dc '0-9' || true)
    b_days_elapsed=$($DATE_CMD +%d 2>/dev/null | sed 's/^0*//' || true)
    # busybox date may not do "+1 month -1 day": fall back to day-diff via jalali-free math
    if [ -z "$b_days_in" ] && [ -n "$b_month" ]; then
        next_month=$($DATE_CMD -d "$b_month-15 +20 day" +%Y-%m 2>/dev/null | cut -c1-7 || true)
        [ -z "$next_month" ] && next_month=$(awk -v m="$b_month" 'BEGIN{split(m,a,"-"); y=a[1]; mo=a[2]+1; if(mo>12){mo=1;y++} printf "%04d-%02d", y, mo}')
        first_next=$("$DATE_CMD" -d "$next_month-01" +%s 2>/dev/null || true)
        first_this=$("$DATE_CMD" -d "$b_month-01" +%s 2>/dev/null || true)
        case "$first_next" in ""|*[!0-9]*) first_next="" ;; esac
        case "$first_this" in ""|*[!0-9]*) first_this="" ;; esac
        if [ -n "$first_next" ] && [ -n "$first_this" ]; then
            b_days_in=$(( (first_next - first_this) / 86400 ))
        fi
    fi
    if [ -n "$b_days_in" ] && [ -n "$b_days_elapsed" ] && [ -d "$BUDGET_USAGE_DIR/day" ]; then
        gb_so_far=$(awk -F'|' '!/^#/ {s+=$4+$5} END{printf "%.2f", s/1073741824}' "$BUDGET_USAGE_DIR"/day/$b_month-*.log 2>/dev/null || true)
        [ -z "$gb_so_far" ] && gb_so_far=0
        proj_gb=$(hn_forecast_gb "$gb_so_far" "$b_days_elapsed" "$b_days_in" 2>/dev/null)
        proj_cost=$(hn_forecast_cost "$proj_gb" "$RATE_FULL" 2>/dev/null)
    fi

    # Build card
    echo "💰 Budget — $tier"
    echo "──────────────"
    printf 'remaining %s GB' "$remain"
    [ -n "$quota" ] && printf ' / %s GB' "$quota"
    [ -n "$pct" ] && printf ' (%s%%)' "$pct"
    echo ""
    [ -n "$expires" ] && echo "expires $expires${days:+ (~${days}d)}"
    [ -n "$drain_gb" ] && echo "drain ${drain_gb} GB/day → ~${proj_days}d left" || echo "drain —"
    [ -n "$proj_cost" ] && [ "$proj_cost" != "0" ] && echo "projected ~$proj_cost Toman this month"
    if [ -n "$exhaust_greg" ]; then
        if [ -n "$exhaust_jal" ]; then
            echo "exhaustion $exhaust_greg ($exhaust_jal)"
        else
            echo "exhaustion $exhaust_greg"
        fi
    fi
    case "$tier" in
        exhausted) echo "⛔ exhausted (<0.05 GB) — recharge now" ;;
        urgent) echo "⚠️ urgent — <3 GB / <3d / <7d projected" ;;
        warn) echo "⚡ warn — <10 GB / <7d / <14d projected" ;;
        *) echo "✅ ok" ;;
    esac
}

budget_check() {
    local fields remain days drain_str drain_gb proj_days tier
    fields=$(hn_balance_fields "$BALANCE_REPORT" 2>/dev/null || echo "available=0")
    remain=$(printf '%s\n' "$fields" | sed -n 's/^remain=//p' | head -1)
    days=$(printf '%s\n' "$fields" | sed -n 's/^days=//p' | head -1)
    drain_str=$(printf '%s\n' "$fields" | sed -n 's/^drain=//p' | head -1)
    drain_gb=$(_parse_drain "$drain_str")
    if [ -n "$drain_gb" ] && [ -n "$remain" ] && [ "$drain_gb" != "0" ]; then
        proj_days=$(awk -v r="$remain" -v d="$drain_gb" 'BEGIN{printf "%.1f", r/d}')
    else
        proj_days=""
    fi
    avail=$(printf '%s\n' "$fields" | sed -n 's/^available=//p' | head -1)
    [ "$avail" = "1" ] || return 0
    [ -n "$remain" ] || return 0
    tier=$(hn_budget_tier "$remain" "$days" "$proj_days" 2>/dev/null || echo "ok")
    [ "$tier" = "ok" ] && return 0

    local action cooldown
    case "$tier" in
        exhausted) action="budget_exhausted"; cooldown=0 ;;
        urgent) action="budget_urgent"; cooldown=10800 ;;
        warn) action="budget_warn"; cooldown=21600 ;;
        *) return 0 ;;
    esac
    if [ "$cooldown" -gt 0 ]; then
        hn_cooldown_ok "$BUDGET_STATE" "$cooldown" "$action" || return 0
    fi
    # Build card and send via tg-notify (best-effort)
    card=$(budget_card 2>/dev/null)
    # Use tg-notify if present, else just echo
    if [ -x /data/proxy/tg-notify.sh ]; then
        sh /data/proxy/tg-notify.sh "Budget $tier" "$card" 2>/dev/null || true
    elif [ -x "$(dirname "$0")/tg-notify.sh" ]; then
        sh "$(dirname "$0")/tg-notify.sh" "Budget $tier" "$card" 2>/dev/null || true
    fi
    [ "$cooldown" -gt 0 ] && hn_cooldown_note "$BUDGET_STATE" "$action" 2>/dev/null || true
    # also print card for caller
    printf '%s\n' "$card"
}

case "${1:-}" in
    --report|--card) budget_card ;;
    --check) budget_check ;;
    --tier) hn_budget_tier "${2:-}" "${3:-}" "${4:-}" ;;
    *) budget_card ;;
esac
