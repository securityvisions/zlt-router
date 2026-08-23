#!/bin/sh
# x28-people.sh — household Ledger: per-person usage for a Jalali month.
#
# Output modes:
#   (default)          plain text  — alerts / digest
#   --html [month]     HTML card   — bot (/people · /month · Panel)
#   --freeze <month>   write the rendered page to ledger/J-<month>.txt
#
# Data: owners-d/YYYY-MM-DD rows (person|mac|up|down) — device-granularity,
# written by the nightly roll and the one-shot backfill.
#
# Env seams for tests: USAGE_DIR, HN_OWNERS_FILE, HN_LIB, NOW override via
# PEOPLE_TODAY (Gregorian YYYY-MM-DD).
set -eu

USAGE_DIR="${USAGE_DIR:-/data/proxy/usage}"
OWNERS_D="$USAGE_DIR/owners-d"
LEDGER_DIR="${LEDGER_DIR:-$USAGE_DIR/ledger}"
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$(dirname "$0")/../hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB" 2>/dev/null || true

RATE_FULL=7700
RATE_FRIDAY=4620
[ -r "$USAGE_DIR/billing.conf" ] && . "$USAGE_DIR/billing.conf" 2>/dev/null || true

esc() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }
bar() {  # bar <pct> <width>
    awk -v p="${1:-0}" -v w="${2:-10}" 'BEGIN{
        f=int(p*w/100+0.5); if(f>w)f=w; if(f<0)f=0;
        s=""; for(i=0;i<w;i++) s = s ((i<f)?"▰":"▱"); print s}'
}

mode="text"; jmonth=""
case "${1:-}" in
    --html)  mode="html"; jmonth="${2:-}" ;;
    --freeze) mode="freeze"; jmonth="${2:?month required}" ;;
    *)       jmonth="${1:-}" ;;
esac

if [ -z "$jmonth" ]; then
    greg_today=${PEOPLE_TODAY:-$(date +%F 2>/dev/null)}
    jmonth=$(hn_greg_to_jalali "$greg_today" 2>/dev/null | cut -d- -f1,2 || true)
fi
case "$jmonth" in ????-??) ;; *) echo "Invalid Jalali month: ${jmonth:-none}" >&2; exit 1 ;; esac

range=$(hn_jalali_month_range "$jmonth" 2>/dev/null || true)
if [ -z "$range" ]; then echo "Invalid Jalali month: $jmonth" >&2; exit 1; fi
start_d=$(printf '%s' "$range" | cut -d' ' -f1)
end_d=$(printf '%s' "$range" | cut -d' ' -f2)

today=${PEOPLE_TODAY:-$(date +%F 2>/dev/null)}
if [ -n "$today" ] && [ "$start_d" \> "$today" ] 2>/dev/null; then : # future month
elif [ -n "$today" ] && [ "$end_d" \> "$today" ] 2>/dev/null; then end_d="$today"; fi

jy=$(printf '%s' "$jmonth" | cut -d- -f1)
jm_n=$(printf '%s' "$jmonth" | cut -d- -f2 | sed 's/^0*//')
label=$(hn_jalali_month_label "$jm_n" 2>/dev/null || echo "")
days_in=$(awk -v s="$start_d" -v e="$end_d" 'BEGIN{
    "date -d " s " +%s" | getline se; close("date -d " s " +%s")
    "date -d " e " +%s" | getline ee; close("date -d " e " +%s")
    print int((ee-se)/86400)+1 }' 2>/dev/null || echo "?")

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
RAW="$TMP/raw"

# aggregate across the range: person|mac totals
cur="$start_d"
while [ -n "$cur" ]; do
    [ "$cur" \> "$end_d" ] 2>/dev/null && break
    f="$OWNERS_D/$cur"
    if [ -f "$f" ]; then
        is_fri=$(date -d "$cur" +%u 2>/dev/null || echo 1)
        rate=$RATE_FULL; [ "$is_fri" = "5" ] && rate=$RATE_FRIDAY
        while IFS='|' read -r person mac up down; do
            [ -n "$person" ] || continue
            bytes=$(( ${up:-0} + ${down:-0} ))
            cost=$(awk -v b="$bytes" -v r="$rate" 'BEGIN{printf "%.0f", b/1073741824*r}')
            printf '%s\t%s\t%s\t%s\n' "$person" "$mac" "$bytes" "$cost" >> "$RAW"
        done < "$f"
    fi
    nxt=$(date -d "$cur +1 day" +%F 2>/dev/null || break)
    [ -z "$nxt" ] && break; [ "$nxt" = "$cur" ] && break; [ "$nxt" = "$start_d" ] && break
    cur="$nxt"
done

AGG="$TMP/agg"
if [ -s "$RAW" ]; then
    awk -F'\t' '{ u[$1]+=$3; c[$1]+=$4; n[$1]++ }
                 END { for(p in u) printf "%s\t%d\t%d\n", p, u[p], c[p] }' "$RAW" \
        | sort -t "$(printf '\t')" -k2,2 -nr > "$AGG"
fi


hdr() {
    if [ "$mode" = "html" ]; then
        printf '<b>👥 دفتر %s %s</b> · %s روز · <i>%s … %s</i>\n' "$(esc "$label")" "$(esc "$jy")" "$(esc "$days_in")" "$(esc "$start_d")" "$(esc "$end_d")"
    else
        printf '👥 People — %s (%s)\nrange %s to %s\n' "$jmonth" "$label" "$start_d" "$end_d"
    fi
}
no_data() { hdr; if [ "$mode" = "text" ]; then echo "(no usage data for this month yet)"; fi; return 0; }

render_row_html() {  # render_row_html <person> <bytes> <cost> <max_bytes>
    local gb pct bars
    gb=$(awk -v b="$2" 'BEGIN{printf "%.1f", b/1073741824}')
    pct=$(awk -v b="$2" -v m="$4" 'BEGIN{print (m>0)? int(b/m*100):0}')
    bars=$(bar "$pct" 10)
    printf '%s <code>%s</code>  %.1f GB · %s T · %s%%\n' \
        "$(esc "$1")" "$bars" "$gb" "$(printf "%'d" "$3" 2>/dev/null || printf '%s' "$3")" "$pct"
}
render_row_text() {
    local gb
    gb=$(awk -v b="$2" 'BEGIN{printf "%.2f", b/1073741824}')
    printf '%-12s %7s GB %9d T\n' "$1" "$gb" "$3"
}

if [ ! -s "$AGG" ]; then no_data
    [ "$mode" = "freeze" ] && exit 1
    exit 0
fi

total_bytes=$(awk -F'\t' '{s+=$2} END{print s+0}' "$AGG")
total_cost=$(awk -F'\t' '{s+=$3} END{print s+0}' "$AGG")
total_gb=$(awk -v b="$total_bytes" 'BEGIN{printf "%.1f", b/1073741824}')

hdr
[ "$mode" = "text" ] && echo "range $start_d to $end_d"
max_bytes=$(awk -F'\t' 'BEGIN{m=0} {if($2>m)m=$2} END{print m}' "$AGG")

if [ "$mode" = "html" ]; then
    echo ""
    while IFS="$(printf '\t')" read -r person bytes cost; do
        [ "${bytes:-0}" -gt 0 ] 2>/dev/null || continue
        render_row_html "$person" "$bytes" "$cost" "$max_bytes"
    done < "$AGG"
    echo "<i>total <b>${total_gb} GB</b> · $(printf "%'d" "$total_cost" 2>/dev/null || echo "$total_cost") Toman</i>"
else
    echo "person        GB      Toman"
    while IFS="$(printf '\t')" read -r person bytes cost; do
        [ "${bytes:-0}" -gt 0 ] 2>/dev/null || continue
        render_row_text "$person" "$bytes" "$cost"
    done < "$AGG"
    total_gb=$(awk -v b="$total_bytes" 'BEGIN{printf "%.2f", b/1073741824}')
    printf '%-12s %7s GB %9d T\n' "TOTAL" "$total_gb" "$total_cost"
fi

# breakdown per person (HTML only): expandable per-device lines
if [ "$mode" = "html" ] && [ -s "${RAW:-}" ]; then
    echo ""
    echo "<blockquote expandable>"
    awk -F'\t' '{ u[$1 SUBSEP $2]+=$3 } END { for(k in u){ split(k,a,SUBSEP); print a[1] "\t" a[2] "\t" u[k] } }' "$RAW" \
        | sort | while IFS="$(printf '\t')" read -r person mac bytes; do
            case "$mac" in [0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]:[0-9A-Fa-f][0-9A-Fa-f]) ;; *) continue ;; esac
            case "${bytes:-}" in ''|[!0-9]*) continue ;; esac
            [ "${bytes:-0}" -gt 0 ] || continue
            gb=$(awk -v b="$bytes" 'BEGIN{printf "%.1f", b/1073741824}')
            printf '%s · <code>%s</code> · %s GB\n' "$(esc "$person")" "$(esc "$mac")" "$gb"
        done
    echo "</blockquote>"
fi

# freeze mode: caller redirects stdout into ledger/J-<month>.txt
exit 0
