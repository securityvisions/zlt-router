#!/bin/sh
# Samantel package balance - multi-package aware, cached token, realtime depletion monitor
#
# Units: Remain counters are KiB. BalanceValue = REMAINING (negative), GrossBal = quota.
#   quota  GiB = |GrossBal|     / DIV
#   remain GiB = |BalanceValue| / DIV
#
# Modes:
#   --report   print rich report (stdout)
#   --daily    send report + snapshot history + tier alert (cron 07:00)
#   --check    tier alert on confirmed numbers only
#   --monitor  realtime depletion estimate + tier alert (cron */15)
#
# Memory/storage: no resident processes, state in /tmp, tiny text history log.
. /etc/samantel.conf 2>/dev/null || exit 1

DIV="${BALANCE_DIV:-1048576}"
WARN_GB="${BALANCE_WARN_GB:-10}"
URGENT_GB="${BALANCE_URGENT_GB:-3}"
WARN_DAYS="${BALANCE_WARN_DAYS:-7}"
URGENT_DAYS="${BALANCE_URGENT_DAYS:-3}"
RATE_ALERT_GBH="${BALANCE_RATE_ALERT_GBH:-5}"
REFRESH_MIN="${MONITOR_REFRESH_MIN:-60}"

TOKEN_FILE=/tmp/samantel_token
ANCHOR=/tmp/balance_anchor
TIER_STATE=/tmp/balance_tier
RATE_STATE=/tmp/balance_rate
HIST_DIR=/etc/balance-log
LOGF=/tmp/balance.log

log() { echo "[$(date '+%F %T')] $*" >> "$LOGF"; }

# ---------- auth: cached access token ----------
login_token() {
    local R T C L S A
    R=$(curl -s -m 12 -D - "https://pwa.samantel.ir/api/auth/csrf" | tr -d "\r")
    T=$(echo "$R" | sed -n "/^$/,\$p" | sed "1d" | sed -n 's/.*"csrfToken":"\([^"]*\)".*/\1/p')
    [ -z "$T" ] && return 1
    C=$(echo "$R" | sed -n "1,/^$/p" | grep -i "^set-cookie:" | sed "s/^[Ss]et-[Cc]ookie: //; s/;.*//" | tr "\n" ";")
    L=$(curl -s -m 15 -D - -b "$C" --data-urlencode "csrfToken=$T" \
        --data-urlencode "phoneNumber=$SAMANTEL_PHONE" \
        --data-urlencode "password=$SAMANTEL_PASS" \
        --data-urlencode "isOtp=false" \
        --data-urlencode "callbackUrl=https://pwa.samantel.ir/" \
        --data-urlencode "json=true" \
        "https://pwa.samantel.ir/api/auth/callback/credentials" | tr -d "\r")
    S=$(echo "$L" | sed -n "1,/^$/p" | grep -i "^set-cookie:" | sed "s/^[Ss]et-[Cc]ookie: //; s/;.*//" | tr "\n" ";")
    A=$(curl -s -m 12 -b "$S" "https://pwa.samantel.ir/api/auth/session" | sed -n 's/.*"accessToken":"\([^"]*\)".*/\1/p')
    [ -z "$A" ] && return 1
    # cache with ~28d expiry; a 401 later triggers re-login anyway
    echo "$(( $(date +%s) + 28*86400 )) $A" > "$TOKEN_FILE"
    chmod 600 "$TOKEN_FILE" 2>/dev/null
    echo "$A"
}

get_token() {
    local texp tok
    if [ -f "$TOKEN_FILE" ]; then
        read -r texp tok < "$TOKEN_FILE"
        if [ -n "$tok" ] && { [ -z "$texp" ] || [ "$(date +%s)" -lt "$texp" ]; }; then
            echo "$tok"
            return 0
        fi
    fi
    login_token
}

# ---------- fetch Remain with auth retry ----------
fetch_remain() {
    local tok body
    tok=$(get_token) || return 1
    body=$(curl -s -m 15 -H "Authorization: Bearer $tok" \
        "https://pwa.samantel.ir/api/SamantelApi/Remain?phoneNumber=$SAMANTEL_PHONE")
    [ -z "$body" ] && return 1
    if echo "$body" | grep -q '"statusCode":6'; then
        rm -f "$TOKEN_FILE"
        tok=$(get_token) || return 1
        body=$(curl -s -m 15 -H "Authorization: Bearer $tok" \
            "https://pwa.samantel.ir/api/SamantelApi/Remain?phoneNumber=$SAMANTEL_PHONE")
    fi
    echo "$body"
}

# rows sorted by remaining desc: quota_gb|remain_gb|expiry (tabs)
balance_rows() {
    fetch_remain | jq -r --argjson d "$DIV" '
        [.result[] | select(.BalanceName | contains("Benefit Data")) |
         ((.GrossBal|tonumber|fabs)/$d|floor) as $q |
         ((.BalanceValue|tonumber|fabs)/$d*10|round/10) as $r |
         [$q, $r, .ExpDate[0:10]]]
        | sort_by(-(.[1]))
        | .[] | @tsv'
}

# ---------- row helpers (rows on stdin) ----------
rows_total()    { awk -F"$(printf '\t')" '{s+=$2} END{printf "%.1f", s}'; }
rows_mainline() { head -1; }
rows_min_days() {
    local exp_epoch
    while IFS="$(printf '\t')" read -r q r e; do
        [ -z "$e" ] && continue
        exp_epoch=$(date -d "${e} 00:00:00" +%s 2>/dev/null)
        [ -n "$exp_epoch" ] && echo $(( (exp_epoch - $(date +%s)) / 86400 ))
    done | sort -n | head -1
}

# ---------- realtime usage (nlbw total, all traffic) ----------
nlbw_total() {
    /usr/sbin/nlbw -c json -g mac 2>/dev/null | jq -r '[.data[] | .[2] + .[4]] | add // 0'
}

# ---------- ISP-observed drain rate from history (skips package jumps) ----------
drain_rate() {
    local f
    f="$HIST_DIR/$(date +%Y-%m).log"
    [ -f "$f" ] || { echo 0; return; }
    awk -F'|' '
        NR>1 { diff = prev - $2; if (diff > 0.05) { used += diff; days++ } }
        { prev = $2 }
        END { if (days>0) printf "%.2f", used/days; else print 0 }
    ' "$f"
}

project_days() {  # total rate -> days (99999 = infinite)
    if awk -v r="$2" 'BEGIN{exit !(r>0.01)}'; then
        awk -v t="$1" -v r="$2" 'BEGIN{printf "%d", t/r}'
    else
        echo 99999
    fi
}

# ---------- history snapshot ----------
snapshot_history() {
    local f today total
    mkdir -p "$HIST_DIR" 2>/dev/null
    f="$HIST_DIR/$(date +%Y-%m).log"
    today=$(date +%Y-%m-%d)
    total="$1"
    [ -z "$total" ] && return 1
    if [ -f "$f" ]; then
        grep -v "^$today|" "$f" > "$f.tmp" 2>/dev/null && mv "$f.tmp" "$f"
    fi
    echo "$today|$total" >> "$f"
}

# ---------- anchor (confirmed ISP reading + nlbw point) ----------
set_anchor_from_rows() {
    local rows total mainq min_days nbw
    rows=$(cat)
    [ -z "$rows" ] && return 1
    total=$(echo "$rows" | rows_total)
    mainq=$(echo "$rows" | rows_mainline | cut -f1)
    min_days=$(echo "$rows" | rows_min_days)
    [ -z "$min_days" ] && min_days=9999
    nbw=$(nlbw_total)
    [ -z "$nbw" ] && nbw=0
    echo "$(date +%s)|$total|$mainq|$nbw|$min_days" > "$ANCHOR"
    snapshot_history "$total"
}

estimate_remaining() {
    [ -f "$ANCHOR" ] || return 1
    local aexp atotal amain anbw amin nbw used
    IFS='|' read -r aexp atotal amain anbw amin < "$ANCHOR"
    nbw=$(nlbw_total)
    used=$(awk -v c="$nbw" -v a="$anbw" 'BEGIN{d=c-a; print (d<0)?0:d/1073741824}')
    awk -v t="$atotal" -v u="$used" 'BEGIN{r=t-u; print (r<0)?0:r}'
}

# ---------- tiers ----------
decide_tier() {  # total pct min_days proj
    local total="$1" pct="$2" min_days="$3" proj="$4"
    awk -v t="$total" 'BEGIN{exit !(t<0.05)}'     && { echo exhausted; return; }
    awk -v t="$total" -v u="$URGENT_GB" 'BEGIN{exit !(t<u)}' && { echo urgent; return; }
    [ "$min_days" -lt "$URGENT_DAYS" ]            && { echo urgent; return; }
    awk -v p="$proj" 'BEGIN{exit !(p<7)}'         && { echo urgent; return; }
    awk -v t="$total" -v w="$WARN_GB" 'BEGIN{exit !(t<w)}'   && { echo warn; return; }
    [ "$min_days" -lt "$WARN_DAYS" ]              && { echo warn; return; }
    awk -v p="$proj" 'BEGIN{exit !(p<14)}'        && { echo warn; return; }
    awk -v p="$pct" 'BEGIN{exit !(p<25)}'         && { echo notice; return; }
    awk -v p="$proj" 'BEGIN{exit !(p<30)}'        && { echo notice; return; }
    echo none
}

tier_msg() {  # tier total pct min_days proj rate
    local tier="$1" total="$2" pct="$3" min_days="$4" proj="$5" rate="$6"
    local dstr="~∞"
    [ "$proj" != "99999" ] && dstr="~${proj}d"
    case "$tier" in
        notice)    echo "🔶 Samantel notice: ${total} GB left (${pct}%), ${dstr} at current rate." ;;
        warn)      echo "🟠 Samantel warning: ${total} GB left (${pct}%), expires in ${min_days}d, ${dstr} at current rate. Consider renewing." ;;
        urgent)    echo "🔴 Samantel low: ${total} GB left (${pct}%), ${dstr} at current rate. Renew soon — Friday is 40% off!" ;;
        exhausted) echo "📛 Samantel data exhausted! Renew now — Friday is 40% off!" ;;
    esac
}

alert_tier() {  # tier total pct min_days proj rate
    local tier="$1" prev pv nv title body
    prev=$(cat "$TIER_STATE" 2>/dev/null || echo none)
    case "$prev" in none) pv=0;; notice) pv=1;; warn) pv=2;; urgent) pv=3;; exhausted) pv=4;; esac
    case "$tier" in none) nv=0;; notice) nv=1;; warn) nv=2;; urgent) nv=3;; exhausted) nv=4;; esac
    if [ "$nv" -gt "$pv" ]; then
        local total="$2" pct="$3" min_days="$4" proj="$5" rate="$6"
        local dstr="~∞"
        [ "$proj" != "99999" ] && dstr="~${proj}d"
        case "$tier" in
            notice)    title="🔶 Samantel notice"; body="${total} GB left (${pct}%), ${dstr} at current rate." ;;
            warn)      title="🟠 Samantel warning"; body="${total} GB left (${pct}%), expires in ${min_days}d, ${dstr} at current rate. Consider renewing." ;;
            urgent)    title="🔴 Samantel low"; body="${total} GB left (${pct}%), ${dstr} at current rate. Renew soon — Friday is 40% off!" ;;
            exhausted) title="📛 Data exhausted"; body="Renew now — Friday is 40% off!" ;;
        esac
        /root/tg.sh --card "$title" "$body"
    fi
    echo "$tier" > "$TIER_STATE"
}

# ---------- report ----------
build_report() {  # rows on stdin
    local rows total mainq mainr mainexp pct exp_epoch days alive deadn extra msg rate proj
    rows=$(cat)
    [ -z "$rows" ] && { echo "No data packages found."; return 0; }
    total=$(echo "$rows" | rows_total)
    IFS="$(printf '\t')" read -r mainq mainr mainexp <<EOF
$(echo "$rows" | rows_mainline)
EOF
    pct=$(awk -v r="$mainr" -v q="$mainq" 'BEGIN{printf "%d", (q>0)?r/q*100:0}')
    exp_epoch=$(date -d "${mainexp} 00:00:00" +%s 2>/dev/null)
    days=$(( (exp_epoch - $(date +%s)) / 86400 ))
    [ "$days" -lt 0 ] && days=0

    alive=0; deadn=0; extra=""
    while IFS="$(printf '\t')" read -r q r e; do
        [ -z "$q" ] && continue
        if awk -v r="$r" 'BEGIN{exit !(r>0.05)}'; then
            alive=$((alive+1))
            [ "$alive" -gt 1 ] && extra="${extra}
• ${q} GB plan: ${r} GB left · expires ${e}"
        else
            deadn=$((deadn+1))
        fi
    done <<EOF
$rows
EOF

    rate=$(drain_rate)
    if awk -v r="$rate" 'BEGIN{exit !(r>0.01)}'; then
        proj=$(project_days "$total" "$rate")
        rateline="Drain ~${rate} GB/day → ~${proj}d left"
    else
        rateline="Drain: collecting data (snapshots nightly)"
    fi

    msg="📦 Samantel — ${total} GB left across ${alive} plan(s)
Main: ${mainq} GB · ${mainr} GB left (${pct}%) · expires ${mainexp} (~${days}d)${extra}"
    [ "$deadn" -gt 0 ] && msg="${msg}
+${deadn} expired plan(s)"
    msg="${msg}

${rateline} (est. — ISP updates slowly)"
    echo "$msg"
}

report_text() { balance_rows | build_report; }

# ---------- confirmed-number tier check ----------
tier_from_rows() {  # rows on stdin
    local rows total mainq mainr mainexp min_days pct rate proj
    rows=$(cat)
    [ -z "$rows" ] && return 0
    total=$(echo "$rows" | rows_total)
    IFS="$(printf '\t')" read -r mainq mainr mainexp <<EOF
$(echo "$rows" | rows_mainline)
EOF
    min_days=$(echo "$rows" | rows_min_days)
    [ -z "$min_days" ] && min_days=9999
    pct=$(awk -v r="$mainr" -v q="$mainq" 'BEGIN{printf "%d", (q>0)?r/q*100:0}')
    rate=$(drain_rate)
    proj=$(project_days "$total" "$rate")
    alert_tier "$(decide_tier "$total" "$pct" "$min_days" "$proj")" "$total" "$pct" "$min_days" "$proj" "$rate"
}

# ---------- realtime monitor ----------
monitor() {
    local now rows aexp fetched=0
    now=$(date +%s)
    if [ ! -f "$ANCHOR" ]; then
        rows=$(balance_rows) && { echo "$rows" | set_anchor_from_rows; fetched=1; }
    else
        IFS='|' read -r aexp rest < "$ANCHOR"
        if [ $(( now - aexp )) -ge $(( REFRESH_MIN * 60 )) ]; then
            rows=$(balance_rows) && { echo "$rows" | set_anchor_from_rows; fetched=1; }
        fi
    fi

    local est mainq amin atotal amain anbw
    if [ -f "$ANCHOR" ]; then
        IFS='|' read -r aexp atotal amain anbw amin < "$ANCHOR"
        est=$(estimate_remaining)
        mainq=$amain
    else
        rows=$(balance_rows) || exit 1
        est=$(echo "$rows" | rows_total)
        mainq=$(echo "$rows" | rows_mainline | cut -f1)
        amin=$(echo "$rows" | rows_min_days)
        [ -z "$amin" ] && amin=9999
    fi
    [ -z "$est" ] && exit 1

    local pct rate proj tier
    pct=$(awk -v r="$est" -v q="${mainq:-0}" 'BEGIN{printf "%d", (q>0)?r/q*100:0}')
    rate=$(drain_rate)
    proj=$(project_days "$est" "$rate")
    tier=$(decide_tier "$est" "$pct" "${amin:-9999}" "$proj")
    alert_tier "$tier" "$est" "$pct" "${amin:-9999}" "$proj" "$rate"

    # realtime rate alert (between monitor runs)
    local last_t last_nbw nbw rrate
    if [ -f "$RATE_STATE" ]; then
        IFS='|' read -r last_t last_nbw < "$RATE_STATE"
    fi
    nbw=$(nlbw_total)
    if [ -n "$last_t" ] && [ -n "$last_nbw" ] && [ $(( now - last_t )) -gt 60 ]; then
        rrate=$(awk -v c="$nbw" -v p="$last_nbw" -v dt="$(( now - last_t ))" \
            'BEGIN{d=(c-p)/1073741824; hr=dt/3600; print (hr>0)?d/hr:0}')
        awk -v r="$rrate" -v t="$RATE_ALERT_GBH" 'BEGIN{exit !(r>=t)}' && \
        awk -v e="$est" 'BEGIN{exit !(e<30)}' && {
            last_a=$(cat /tmp/balance_rate_alert 2>/dev/null || echo 0)
            if [ $(( now - last_a )) -ge 14400 ]; then
                hleft=$(awk -v e="$est" -v r="$rrate" 'BEGIN{printf "%d", (r>0)?e/r:0}')
                /root/tg.sh --card "⚡ High usage" "Rate: ~${rrate} GB/h → ~${hleft}h left. Pause heavy downloads to save data."
                echo "$now" > /tmp/balance_rate_alert
            fi
        }
    fi
    echo "$now|$nbw" > "$RATE_STATE"

    # Refresh the panel balance cache (Q3)
    if [ "$fetched" = "1" ] && [ -n "$rows" ]; then
        # rows already fetched — write cache for free
        echo "$rows" | build_report > /tmp/balance_report 2>/dev/null
        date +%s > /tmp/balance_report.ts 2>/dev/null
    elif [ ! -f /tmp/balance_report.ts ] || [ $(( now - $(cat /tmp/balance_report.ts 2>/dev/null || echo 0) )) -ge 900 ]; then
        # cache older than 15 min — one extra API call
        report_text > /tmp/balance_report 2>/dev/null
        date +%s > /tmp/balance_report.ts 2>/dev/null
    fi
}

# ---------- CLI ----------
case "$1" in
    --report) report_text | tee /tmp/balance_report; date +%s > /tmp/balance_report.ts ;;
    --cache)  report_text > /tmp/balance_report; date +%s > /tmp/balance_report.ts ;;
    --daily)
        rows=$(balance_rows)
        if [ -z "$rows" ]; then
            /root/tg.sh --card "⚠️ Samantel check failed" "Check credentials/network."
            exit 1
        fi
        echo "$rows" | set_anchor_from_rows
        msg=$(echo "$rows" | build_report)
        [ -n "$msg" ] && /root/tg.sh "$msg"
        echo "$rows" | tier_from_rows
        ;;
    --check)
        rows=$(balance_rows) || { echo "Samantel check failed — check credentials/network." >&2; exit 1; }
        echo "$rows" | set_anchor_from_rows
        echo "$rows" | tier_from_rows
        ;;
    --monitor) monitor ;;
    *) echo "usage: $0 {--report|--daily|--check|--monitor}" >&2 ;;
esac
