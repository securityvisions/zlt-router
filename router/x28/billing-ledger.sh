#!/bin/sh
# billing-ledger.sh — Dedicated Household Billing & Accounting Ledger for X28.
[ -n "${_BILLING_LEDGER_LOADED:-}" ] && return 0 2>/dev/null || true
_BILLING_LEDGER_LOADED=1
#
# Bounded Domain: Bandwidth cost calculation, Jalali calendar month day-walking,
# per-person/device quota attribution, and Friday discount accounting.
# Completely decoupled from WAN Outage/SLA and cellular carrier recovery.
#
# Interfaces:
#   billing-ledger.sh rates
#   billing-ledger.sh query <jalali_month>
#   billing-ledger.sh total <jalali_month>
#   billing-ledger.sh tier <remain_gb> <expiry_days> <projected_days>

USAGE_DIR="${USAGE_DIR:-/data/proxy/usage}"
OWNERS_D="$USAGE_DIR/owners-d"

RATE_FULL="${RATE_FULL:-7700}"
RATE_FRIDAY="${RATE_FRIDAY:-4620}"
[ -r "$USAGE_DIR/billing.conf" ] && . "$USAGE_DIR/billing.conf" 2>/dev/null || true

HN_LIB="${HN_LIB:-/root/hnlib.sh}"
if ! command -v hn_jalali_month_range >/dev/null 2>&1; then
    for _l in "$HN_LIB" /data/proxy/hnlib.sh "$(dirname "$0")/../hnlib.sh"; do
        [ -f "$_l" ] && . "$_l" && break
    done
fi

# Day-of-week calculation (5 = Friday)
dow_u() {
    local d="$1" y m day
    y=$(printf '%s' "$d" | cut -d- -f1)
    m=$(printf '%s' "$d" | cut -d- -f2 | sed 's/^0*//')
    day=$(printf '%s' "$d" | cut -d- -f3 | sed 's/^0*//')
    awk -v y="$y" -v m="$m" -v d="$day" 'BEGIN {
        if (m < 3) { m += 12; y -= 1 }
        c = int(y / 100); y = y % 100
        w = (d + int(13 * (m + 1) / 5) + y + int(y / 4) + int(c / 4) + 5 * c) % 7
        w = (w + 6) % 7
        print w
    }'
}

billing_rates() {
    printf 'RATE_FULL=%s\nRATE_FRIDAY=%s\n' "$RATE_FULL" "$RATE_FRIDAY"
}

billing_budget_tier() {
    local remain="${1:-}" expiry="${2:-}" proj="${3:-}"
    [ -z "$remain" ] && remain=9999
    [ -z "$expiry" ] && expiry=9999
    [ -z "$proj" ] && proj=9999
    awk -v r="$remain" -v e="$expiry" -v p="$proj" '
    BEGIN{
        if (r+0 < 0.05) { print "exhausted"; exit }
        if (r+0 < 3 || e+0 < 3 || p+0 < 7) { print "urgent"; exit }
        if (r+0 < 10 || e+0 < 7 || p+0 < 14) { print "warn"; exit }
        print "ok"
    }'
}

billing_owner_of() {
    local mac="${1:-}" f="${2:-${HN_OWNERS_FILE:-/data/proxy/owners.conf}}" want line
    [ -n "$mac" ] || { echo ""; return 0; }
    want=$(printf '%s' "$mac" | tr 'A-Z' 'a-z')
    [ -f "$f" ] || { echo ""; return 0; }
    line=$(grep -i "^$(printf '%s' "$want" | sed 's/[][\.*^$]/\\&/g')|" "$f" 2>/dev/null | head -1 || true)
    [ -z "$line" ] && { echo ""; return 0; }
    printf '%s' "$line" | cut -d'|' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
}

billing_day_rows() {
    local d="${1:?date required}"
    local f="$OWNERS_D/$d"
    [ -f "$f" ] && { cat "$f"; return 0; }
    local today="${PEOPLE_TODAY:-$(date +%F 2>/dev/null || echo "")}"
    [ "$d" = "$today" ] || return 0
    f="$USAGE_DIR/day/$d"
    [ -f "$f" ] || return 0
    local owners="${HN_OWNERS_FILE:-/data/proxy/owners.conf}"
    local mac ip name up down person want line
    while IFS='|' read -r mac ip name up down; do
        case "$mac" in "#"*|"") continue ;; esac
        [ -n "$mac" ] || continue
        person=""
        if [ -f "$owners" ]; then
            want=$(printf '%s' "$mac" | tr 'A-Z' 'a-z')
            line=$(grep -i "^$(printf '%s' "$want" | sed 's/[][\.*^$]/\\&/g')|" "$owners" 2>/dev/null | head -1 || true)
            person=$(printf '%s' "$line" | cut -d'|' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')
        fi
        [ -n "$person" ] || person="unassigned"
        printf '%s|%s|%s|%s\n' "$person" "$mac" "${up:-0}" "${down:-0}"
    done < "$f"
}

billing_query() {
    local jmonth="${1:?month required}"
    case "$jmonth" in ????-??) ;; *) return 1 ;; esac

    local range start_d end_d jy jm_n days_in today tmpf daytmp jd g cur is_fri rate person mac up down bytes cost
    range=$(hn_jalali_month_range "$jmonth" 2>/dev/null || true)
    [ -z "$range" ] && return 1
    start_d=$(printf '%s' "$range" | cut -d' ' -f1)
    end_d=$(printf '%s' "$range" | cut -d' ' -f2)

    today="${PEOPLE_TODAY:-$(date +%F 2>/dev/null || echo "")}"
    if [ -n "$today" ] && [ "$start_d" \> "$today" ] 2>/dev/null; then :
    elif [ -n "$today" ] && [ "$end_d" \> "$today" ] 2>/dev/null; then end_d="$today"; fi

    jy=$(printf '%s' "$jmonth" | cut -d- -f1)
    jm_n=$(printf '%s' "$jmonth" | cut -d- -f2 | sed 's/^0*//')
    days_in=40

    tmpf=$(mktemp 2>/dev/null || echo "/tmp/bq.$$")
    : > "$tmpf"
    daytmp=$(mktemp 2>/dev/null || echo "/tmp/bdt.$$")

    jd=1
    while [ "$jd" -le "$days_in" ]; do
        g=$(hn_jalali_to_greg "$(printf '%04d-%02d-%02d' "$jy" "$jm_n" "$jd")" 2>/dev/null || true)
        [ -n "$g" ] || { jd=$((jd+1)); continue; }
        [ "$g" \> "$end_d" ] 2>/dev/null && break
        cur="$g"
        billing_day_rows "$cur" > "$daytmp" 2>/dev/null || true
        if [ -s "$daytmp" ]; then
            is_fri=$(dow_u "$cur")
            rate=$RATE_FULL; [ "$is_fri" = "5" ] && rate=$RATE_FRIDAY
            while IFS='|' read -r person mac up down; do
                [ -n "$person" ] || continue
                bytes=$(( ${up:-0} + ${down:-0} ))
                cost=$(awk -v b="$bytes" -v r="$rate" 'BEGIN{printf "%.0f", b/1073741824*r}')
                printf '%s\t%s\t%s\t%s\n' "$person" "$mac" "$bytes" "$cost" >> "$tmpf"
            done < "$daytmp"
        fi
        jd=$((jd + 1))
    done
    rm -f "$daytmp"

    if [ -s "$tmpf" ]; then
        awk -F'\t' '{ u[$1]+=$3; c[$1]+=$4 } END { for(p in u) printf "%s\t%.0f\t%.0f\n", p, u[p], c[p] }' "$tmpf" \
            | sort -t"$(printf '\t')" -k2,2 -nr
    fi
    rm -f "$tmpf"
}

billing_month_total() {
    local jmonth="${1:?month required}"
    local q
    q=$(billing_query "$jmonth" 2>/dev/null || true)
    [ -n "$q" ] || { printf '0\t0\n'; return 0; }
    printf '%s\n' "$q" | awk -F'\t' '{ b+=$2; c+=$3 } END { printf "%.0f\t%.0f\n", b+0, c+0 }'
}

# Compatibility aliases
hn_budget_tier() { billing_budget_tier "$@"; }
hn_owner_of() { billing_owner_of "$@"; }
ledger_rates() { billing_rates; }
ledger_day_rows() { billing_day_rows "$@"; }
ledger_query() { billing_query "$@"; }
ledger_month_total() { billing_month_total "$@"; }

case "${0##*/}" in
    billing-ledger.sh)
        case "${1:-}" in
            rates) billing_rates ;;
            query) billing_query "${2:?jmonth required}" ;;
            total) billing_month_total "${2:?jmonth required}" ;;
            tier)  billing_budget_tier "${2:-}" "${3:-}" "${4:-}" ;;
            *)
                echo "Usage: $0 {rates|query <jmonth>|total <jmonth>|tier <remain> <exp> <proj>}" >&2
                exit 1
                ;;
        esac
        ;;
esac
