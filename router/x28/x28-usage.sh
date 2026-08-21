#!/bin/sh
# x28-usage.sh — per-device usage + Toman cost card (reader, no side effects).
# Usage: x28-usage.sh [today|week|month]   (default: today)
# Rates come from billing.conf (Toman per GiB; full-day and Friday rates).
# Canonical copy: router/x28/x28-usage.sh — deploys to /data/proxy/usage/.

DIR=/data/proxy/usage
MODE="${1:-today}"

RATE_FULL=7700
RATE_FRIDAY=4620
[ -r "$DIR/billing.conf" ] && . "$DIR/billing.conf"

# days to aggregate (busybox date: -d support varies — fall back to today)
days=""
case "$MODE" in
    today) days="$(date +%F)" ;;
    week)
        for i in 0 1 2 3 4 5 6; do
            d=$(date -d "-$i day" +%F 2>/dev/null) || break
            days="$days $d"
        done
        [ -z "$days" ] && days="$(date +%F)" ;;
    month)
        for f in "$DIR"/day/$(date +%Y-%m)-*; do [ -f "$f" ] && days="$days ${f##*/}"; done ;;
    *) days="$(date +%F)" ;;
esac

tmp=$(mktemp)
for d in $days; do
    f="$DIR/day/$d"
    [ -f "$f" ] || continue
    dow=$(date -d "$d" +%u 2>/dev/null || echo 1)
    rate=$RATE_FULL
    [ "$dow" = "5" ] && rate=$RATE_FRIDAY
    awk -F"|" -v rate="$rate" '
        /^#/ { next }
        NF >= 5 {
            key = $2
            up[key] += $4; dn[key] += $5
            cost[key] += ($4 + $5) / 1073741824 * rate
            if ($3 != "" && $3 != "unknown") name[key] = $3
            if (!(key in seen)) { order[++n] = key; seen[key] = 1 }
        }
        END { for (i = 1; i <= n; i++) {
            k = order[i]
            printf "%s|%s|%d|%d|%.0f\n", k, (name[k] != "" ? name[k] : k), up[k], dn[k], cost[k]
        } }' "$f" >> "$tmp"
done

label="$MODE"
[ "$MODE" = "today" ] && label="$(date +%F)"

echo "Usage $label"
echo "--------------------------------"
echo "device               GB     Toman"
awk -F"|" '
    {
        tot += $3 + $4; cost += $5
        printf "%-16s %7.2f %9d\n", substr($2, 1, 16), ($3 + $4) / 1073741824, $5
        n++
    }
    END {
        if (n) printf "%-16s %7.2f %9d\n", "TOTAL", tot / 1073741824, cost
        else print "(no data collected yet)"
    }' "$tmp"

if [ "$MODE" = "today" ]; then
    # calibration: attributed vs modem-exact WAN totals since boot
    . /data/proxy/x28lib.sh 2>/dev/null
    if x28_session >/dev/null 2>&1; then
        rx=$(curl -s -m 6 -H "Content-Type: application/json" \
            -d "{\"cmd\":18,\"method\":\"GET\",\"sessionId\":\"$X28_SID\",\"language\":\"en\"}" \
            "$X28_BASE" 2>/dev/null | sed -n 's/.*"rxBytes":"\([0-9]*\)".*/\1/p' | head -1)
        if [ -n "$rx" ] && [ "$rx" -gt 0 ]; then
            attr=$(awk -F"|" '{ s += $3 + $4 } END { print s + 0 }' "$tmp")
            echo "--------------------------------"
            echo "WAN since boot: $((rx / 1073741824)) GB (modem, exact)"
            echo "Attributed:     $((attr * 100 / rx))% (conntrack sampling)"
        fi
    fi
fi

rm -f "$tmp"
