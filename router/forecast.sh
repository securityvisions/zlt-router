#!/bin/sh
# forecast.sh — month-end cost projection + budget alert.
#
# Canonical copy lives in this repo (router/forecast.sh); deployed to the
# AX3000T as /root/forecast.sh (cron, daily). Projects this month's usage to
# month-end by linear run-rate, prices it with the billing rates, and alerts
# when the projection crosses the budget threshold (cooldown-gated).

BCONF="${BCONF:-/etc/billing.conf}"
[ -f "$BCONF" ] && . "$BCONF"
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] && . "$HN_LIB"

USAGE_DIR="${USAGE_DIR:-/etc/usage-log}"
STATE="${FORECAST_STATE:-/tmp/forecast.state}"
BUDGET_TOMAN="${BUDGET_TOMAN:-300000}"
COOLDOWN_S="${FORECAST_COOLDOWN_S:-86400}"

rate_for() {  # rate_for <friday> — the active per-GB rate
    if [ "$1" = "yes" ]; then echo "${RATE_FRIDAY_TOMAN:-4620}"; else echo "${RATE_FULL_TOMAN:-7700}"; fi
}

# fc_month_totals — prints "gb|rate|days_elapsed|days_in_month" for this month.
fc_month_totals() {
    local ym rate m y gb days el
    ym=$(date +%Y-%m)
    y=${ym%%-*}; m=${ym##*-}
    if [ "$(date +%u)" = "5" ]; then rate=$(rate_for yes); else rate=$(rate_for no); fi
    gb=$(awk -F'|' '$3+0>0 {t+=$3} END{printf "%.3f", t/1073741824}' "$USAGE_DIR/$ym.log" 2>/dev/null)
    [ -z "$gb" ] && gb=0
    el=$(date +%d | sed 's/^0*//')
    [ -z "$el" ] && el=1
    days=$(cal "$m" "$y" 2>/dev/null | awk 'NF {d=$NF} END{print d+0}')
    [ -z "$days" ] || [ "$days" = "0" ] && days=30
    echo "$gb|$rate|$el|$days"
}

fc_report() {
    local t gb rate el days proj_gb proj_tom
    t=$(fc_month_totals)
    gb=$(echo "$t" | cut -d'|' -f1); rate=$(echo "$t" | cut -d'|' -f2)
    el=$(echo "$t" | cut -d'|' -f3); days=$(echo "$t" | cut -d'|' -f4)
    proj_gb=$(hn_forecast_gb "$gb" "$el" "$days")
    proj_tom=$(hn_forecast_cost "$proj_gb" "$rate")
    echo "📊 Month-end forecast"
    echo "Used: ${gb} GB in ${el}/${days} days"
    echo "Projected: <b>${proj_gb} GB</b> ≈ <b>${proj_tom} Toman</b>"
    echo "Budget: ${BUDGET_TOMAN} Toman"
}

main() {
    local t gb rate el days proj_gb proj_tom decision
    t=$(fc_month_totals)
    gb=$(echo "$t" | cut -d'|' -f1); rate=$(echo "$t" | cut -d'|' -f2)
    el=$(echo "$t" | cut -d'|' -f3); days=$(echo "$t" | cut -d'|' -f4)
    proj_gb=$(hn_forecast_gb "$gb" "$el" "$days")
    proj_tom=$(hn_forecast_cost "$proj_gb" "$rate")
    decision=$(hn_budget_decision "$proj_tom" "$BUDGET_TOMAN")
    if [ "$decision" = "ALERT|budget" ] && hn_cooldown_ok "$STATE" "$COOLDOWN_S" budget; then
        hn_cooldown_note "$STATE" budget
        [ -x /root/tg.sh ] && /root/tg.sh --text "⚠️ Projected month-end cost <b>${proj_tom} Toman</b> is at/over the ${BUDGET_TOMAN} budget." >/dev/null 2>&1
    fi
    echo "$decision"
}

case "${1:-}" in
    --report) fc_report ;;
    *) main ;;
esac
