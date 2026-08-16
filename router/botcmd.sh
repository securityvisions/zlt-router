#!/bin/sh
# Interactive Telegram bot - decorated panel + commands (long polling)
# Cards: HTML parse_mode; dashboard entry; heartbeat watchdog stamp.
. /etc/tg.conf 2>/dev/null || exit 1

LOCK=/tmp/botcmd.lock
mkdir "$LOCK" 2>/dev/null || exit 0
echo $$ > /tmp/botcmd.pid
trap 'rm -f /tmp/botcmd.pid /tmp/botcmd.hb; rmdir "$LOCK" 2>/dev/null' EXIT

LOG=/tmp/botcmd.log
log() { echo "[$(date '+%F %T')] $*" >> "$LOG"; }

# ── Rendering core (chat-beauty-v2: shared botlib) ──────────────────────────
. /root/botlib.sh 2>/dev/null || { echo "botlib.sh missing" >&2; exit 1; }
. /root/hnlib.sh 2>/dev/null || { echo "hnlib.sh missing" >&2; exit 1; }

# ── Telegram send (Q12: all botcmd output is HTML) ─────────────────────────
send() {  # send <chat_id> <text> [reply_markup]
    local cid="$1" text="$2" rm="$3"
    set -- curl -s -m 8 "https://api.telegram.org/bot$TOKEN/sendMessage" \
        --data-urlencode "chat_id=$cid" \
        --data-urlencode "text=$text" \
        --data-urlencode "parse_mode=HTML"
    [ -n "$rm" ] && set -- "$@" --data-urlencode "reply_markup=$rm"
    "$@" >> "$LOG" 2>&1 || true
}

answer_cb() {
    curl -s -m 8 "https://api.telegram.org/bot$TOKEN/answerCallbackQuery" \
        --data-urlencode "callback_query_id=$1" >> "$LOG" 2>&1 || true
}

# ── Edit-in-place Panel delivery (chat-beauty-v2 #02) ───────────────────────
PANEL_MSG=0  # 1 while a panel-grid callback is being answered (edit, not send)

panel_post() {  # like send, but records the resulting message_id for edits
    local cid="$1" text="$2" rm="$3" resp mid
    set -- curl -s -m 8 "https://api.telegram.org/bot$TOKEN/sendMessage" \
        --data-urlencode "chat_id=$cid" \
        --data-urlencode "text=$text" \
        --data-urlencode "parse_mode=HTML"
    [ -n "$rm" ] && set -- "$@" --data-urlencode "reply_markup=$rm"
    resp=$("$@" 2>&1) || true
    echo "$resp" >> "$LOG" 2>&1
    mid=$(echo "$resp" | jq -r '.result.message_id // empty' 2>/dev/null)
    [ -n "$mid" ] && echo "$cid $mid" > /tmp/botcmd_panel
}

edit_panel() {  # edit the stored panel message; fresh send + re-store on failure
    local cid="$1" text="$2" rm="$3" pid resp
    read -r _ pid < /tmp/botcmd_panel 2>/dev/null
    [ -z "$pid" ] && { panel_post "$cid" "$text" "$rm"; return; }
    set -- curl -s -m 8 "https://api.telegram.org/bot$TOKEN/editMessageText" \
        --data-urlencode "chat_id=$cid" --data-urlencode "message_id=$pid" \
        --data-urlencode "text=$text" --data-urlencode "parse_mode=HTML"
    [ -n "$rm" ] && set -- "$@" --data-urlencode "reply_markup=$rm"
    resp=$("$@" 2>&1) || true
    echo "$resp" >> "$LOG" 2>&1
    if ! echo "$resp" | grep -q '"ok":true'; then
        panel_post "$cid" "$text" "$rm"
    fi
}

deliver() {  # deliver <chat> <text> <fallback_markup> — panel taps edit in place
    local cid="$1" text="$2" mk="$3"
    if [ "$PANEL_MSG" = 1 ]; then
        edit_panel "$cid" "$text" "$(panel_markup)"
    else
        send "$cid" "$text" "$mk"
    fi
}

# ── Keyboard markups ────────────────────────────────────────────────────────
panel_markup() {
    # 4 rows, domain-ordered (Q8): Network · Data · Billing · Devices
    printf '{"inline_keyboard":['
    printf '[{"text":"📊 Status","callback_data":"status"},{"text":"🟢 Proxy","callback_data":"hyst"}],'
    printf '[{"text":"📈 Usage","callback_data":"usage"},{"text":"💰 Cost","callback_data":"cost"}],'
    printf '[{"text":"🧾 Bill","callback_data":"bill"},{"text":"📦 Balance","callback_data":"balance"}],'
    printf '[{"text":"📱 Clients","callback_data":"clients"},{"text":"💾 Disk","callback_data":"disk"}]'
    printf ']}'
}

back_markup() {
    printf '{"inline_keyboard":[[{"text":"◀ Panel","callback_data":"panel"}]]}'
}

friday_markup() {
    printf '{"inline_keyboard":[[{"text":"✅ Yes","callback_data":"%s_yes"},{"text":"❌ No","callback_data":"%s_no"}]]}' "$1" "$1"
}

set_friday() { sed -i "s/^LAST_FRIDAY=.*/LAST_FRIDAY=$1/" /etc/billing.conf 2>/dev/null; }

# ── Panel entry: dashboard card (Q10 + Q6) ─────────────────────────────────
panel() {
    local chat="$1"
    local bp br bd proxy devcount usage disk dpct dfree load temp

    # balance — parse values for the gauge + day-count (shared hnlib reader)
    bp=0; br="—"; bd=""
    if [ -f /tmp/balance_report ]; then
        local bf series
        bf=$(hn_balance_fields /tmp/balance_report)
        bp=$(hn_balance_field "$bf" pct)
        br=$(hn_balance_field "$bf" remain)
        bd=$(hn_balance_field "$bf" days)
        series=$(hn_balance_series 14 pipe)
    fi

    # proxy — fast SOCKS probe (acceptable latency)
    proxy=$(hn_sys_proxy_state | awk -F'|' '{print ($1=="up") ? "🟢 UP" : "🔴 DOWN"}')

    # devices + usage
    devcount=$(wc -l < /tmp/dhcp.leases 2>/dev/null | tr -d ' ')
    usage=$(/root/usage.sh --today 2>/dev/null | awk -F'|' '{s+=$3} END{printf "%.2f GB", s/1073741824}')
    [ -z "$usage" ] && usage="—"

    # disk + load/temp
    disk=$(hn_sys_disk)
    dpct=${disk%%|*}; dpct=${dpct:-0}
    dfree=${disk##*|}
    load=$(hn_sys_load)
    temp=$(hn_sys_temp_c)

    body=$(dashboard_body "$bp" "$br" "$bd" "$proxy" "$devcount" "$usage" "$dpct" "$dfree" "$load" "$temp" "$series")
    panel_post "$chat" "$(card "<b>🔘 Control Panel</b>" "$body")" "$(panel_markup)"
}

# ── Panel commands ──────────────────────────────────────────────────────────
cmd_status() {
    local load up mem temp diskpct freespace badge body
    load=$(hn_sys_load)
    up=$(hn_sys_uptime)
    mem=$(hn_sys_mem | awk '{printf "%d/%d MB", $1, $2}')
    temp=$(hn_sys_temp_c)
    badge=$(temp_badge "$temp")
    disk=$(hn_sys_disk)
    diskpct=${disk%%|*}
    diskpct=${diskpct:-0}
    freespace=${disk##*|}
    body="Uptime   $(pad "$up" 12)
Load     $(pad "$load" 12)
RAM      $(pad "$mem" 12)
Temp     $(pad "${temp:-?}°C ${badge}" 14)
Storage  $(bar "$diskpct" 10)  ${diskpct}% used (${freespace} free)"
    deliver "$1" "$(card "<b>📡 Router Status</b>" "$body")" "$(back_markup)"
}

cmd_clients() {
    local body mac ip name count=0 today
    today=$(/root/usage.sh --today 2>/dev/null)
    body=$({
        while read -r ts mac ip lname rest; do
            [ -z "$mac" ] && continue
            count=$((count+1))
            name=$(/root/usage.sh --name "$mac")
            [ -z "$name" ] && name="unknown(${mac})"
            bytes=$(echo "$today" | awk -F'|' -v n="$name" '$1==n{b=$3} END{o=(b==""?0:b); print (o<0)?-o:o}')
            printf '%s|0|%s\n' "$name" "$bytes"
        done < /tmp/dhcp.leases
    } | dev_usage_rows)
    [ -z "$body" ] && body="No devices connected."
    deliver "$1" "$(card "<b>📱 Connected Devices</b> (${count})" "$body")" "$(back_markup)"
}

cmd_disk() {
    local body disk dpct freespace
    disk=$(hn_sys_disk)
    dpct=${disk%%|*}; dpct=${dpct:-0}
    freespace=${disk##*|}
    body="Usage $(bar "$dpct")  ${dpct}% (${freespace} free)
$(df -h / | awk 'NR==1{print}')"
    deliver "$1" "$(card "<b>💾 Storage</b>" "$body")" "$(back_markup)"
}

cmd_hyst() {
    local ps state t body
    ps=$(hn_sys_proxy_state)   # "up|<latency>" or "down|"
    state=${ps%%|*}; t=${ps##*|}
    if [ "$state" = "up" ]; then
        body="Hysteria UP (${t}s)"
        deliver "$1" "$(card "<b>🟢 Proxy</b>" "$body")" "$(back_markup)"
    else
        body="Hysteria DOWN"
        deliver "$1" "$(card "<b>🔴 Proxy</b>" "$body")" "$(back_markup)"
    fi
}

cmd_link() {
    local s op tech signal rsrp rsrp5g band plmn body
    s=$(/root/x28link.sh 2>/dev/null)
    if [ -z "$s" ]; then
        deliver "$1" "$(card "<b>📡 Link</b>" "Link reader unavailable.")" "$(back_markup)"
        return
    fi
    fld() { hn_link_field "$s" "$1"; }
    op=$(fld operator); tech=$(fld tech); signal=$(fld signal)
    rsrp=$(fld rsrp); rsrp5g=$(fld rsrp_5g); band=$(fld band); plmn=$(fld plmn)
    body="Operator: <b>${op:-n/a}</b>
Technology: <b>${tech:-n/a}</b>
Signal: <b>${signal:-n/a}</b>/5
LTE RSRP: <b>${rsrp:-n/a}</b> dBm
5G RSRP: <b>${rsrp5g:-n/a}</b> dBm
PLMN: <b>${plmn:-n/a}</b>"
    deliver "$1" "$(card "<b>📡 Link</b>" "$body")" "$(back_markup)"
}

cmd_test() {
    local url="$1" out
    if [ -z "$url" ]; then send "$2" "Usage: /test <url>  e.g. /test google.com"; return; fi
    case "$url" in
        http://*|https://*) : ;;
        *) url="https://$url" ;;
    esac
    out=$(curl -sS -m 10 -o /dev/null -w "HTTP %{http_code} in %{time_total}s (IP %{remote_ip})" "$url" 2>/dev/null)
    [ -z "$out" ] && out="unreachable"
    body=$(printf '%s\n%s' "$(esc "$url")" "$out")
    send "$2" "$(card "<b>🔎 Test</b>" "$body")" ""
}

cmd_usage() {
    local usage body label
    usage=$(/root/usage.sh --today 2>/dev/null)
    if [ -z "$usage" ]; then
        usage=$(/root/usage.sh --raw 2>/dev/null)
        label="current period"
    else
        label="today"
    fi
    if [ -z "$usage" ]; then
        deliver "$1" "$(card "<b>📈 Usage</b>" "No usage data yet.")" "$(back_markup)"
        return
    fi
    body=$(printf '%s' "$usage" | dev_usage_rows)
    deliver "$1" "$(card "<b>📈 Usage</b> (${label})" "$body")" "$(back_markup)"
}

cmd_balance() {
    local body text ts ago bf pct remain quota expires expdays drain series
    if [ -f /tmp/balance_report ]; then
        bf=$(hn_balance_fields /tmp/balance_report)
        pct=$(hn_balance_field "$bf" pct)
        remain=$(hn_balance_field "$bf" remain)
        quota=$(hn_balance_field "$bf" quota)
        expires=$(hn_balance_field "$bf" expires)
        days=$(hn_balance_field "$bf" days)
        expdays=""
        [ -n "$days" ] && expdays="~${days}d"   # balance_body renders (expdays)
        drain=$(hn_balance_field "$bf" drain)
        series=$(hn_balance_series 14 pipe)
        if [ -n "$pct" ] && [ -n "$remain" ]; then
            body=$(balance_body "$pct" "$remain" "$quota" "$expires" "$expdays" "$drain" "$series")
        else
            body=$(cat /tmp/balance_report)
        fi
        ts=$(cat /tmp/balance_report.ts 2>/dev/null || echo 0)
        [ "$ts" -gt 0 ] 2>/dev/null && ago=$(date -d "@$ts" '+%H:%M' 2>/dev/null)
    else
        body=$(/root/balance.sh --report 2>/dev/null)
        [ -z "$body" ] && body="Balance unavailable — no cache yet."
    fi
    text=$(card "<b>📦 Data Balance</b>" "$body")
    [ -n "$ago" ] && text="${text}
<i>cached as of ${ago}</i>"
    deliver "$1" "$text" "$(back_markup)"
}

ask_friday() {  # <chat> <cost|bill>
    local chat="$1" kind="$2" text
    text=$(card "<b>💳 Friday discount?</b>" "7,700 T/GB full · 4,620 T/GB Friday")
    if [ "$PANEL_MSG" = 1 ]; then
        edit_panel "$chat" "$text" "$(friday_markup "$kind")"
    else
        send "$chat" "$text" "$(friday_markup "$kind")"
    fi
}

cost_result() {
    set_friday "$2"
    deliver "$1" "$(card "<b>💰 Cost</b>" "$(/root/billing.sh --today "$2")")" "$(back_markup)"
}
bill_result() {
    set_friday "$2"
    deliver "$1" "$(card "<b>🧾 Bill</b>" "$(/root/billing.sh --month "$2")")" "$(back_markup)"
}

# ── Dispatch ────────────────────────────────────────────────────────────────
handle_cb() {  # <chat> <data> <callback_query_id>
    local chat="$1" data="$2" cqid="$3"
    PANEL_MSG=1  # grid taps edit the stored panel message
    case "$data" in
        panel)    PANEL_MSG=0; panel "$chat" ;;
        status)   cmd_status "$chat" ;;
        usage)    cmd_usage "$chat" ;;
        hyst)     cmd_hyst "$chat" ;;
        clients)  cmd_clients "$chat" ;;
        disk)     cmd_disk "$chat" ;;
        balance)  cmd_balance "$chat" ;;
        cost)     ask_friday "$chat" cost ;;
        bill)     ask_friday "$chat" bill ;;
        cost_yes) cost_result "$chat" yes ;;
        cost_no)  cost_result "$chat" no ;;
        bill_yes) bill_result "$chat" yes ;;
        bill_no)  bill_result "$chat" no ;;
        *)        PANEL_MSG=0 ;;
    esac
    PANEL_MSG=0
    answer_cb "$cqid"
}

# ── Long-poll loop + heartbeat watchdog stamp ───────────────────────────────
OFFSET=0
while :; do
    # Heartbeat stamp (Q7: watcher kills if stale >120s)
    date +%s > /tmp/botcmd.hb

    U=$(curl -s -m 30 "https://api.telegram.org/bot$TOKEN/getUpdates?timeout=25&offset=$OFFSET" 2>/dev/null)
    UID=$(echo "$U" | jq -r '.result[0].update_id // empty' 2>/dev/null)
    [ -z "$UID" ] && { sleep 3; continue; }
    OFFSET=$((UID + 1))

    CQDATA=$(echo "$U" | jq -r '.result[0].callback_query.data // empty' 2>/dev/null)
    if [ -n "$CQDATA" ]; then
        CQID=$(echo "$U" | jq -r '.result[0].callback_query.id' 2>/dev/null)
        FROM=$(echo "$U" | jq -r '.result[0].callback_query.message.chat.id' 2>/dev/null)
        [ "$FROM" != "$CHAT_ID" ] && continue
        log "cb $FROM: $CQDATA"
        handle_cb "$FROM" "$CQDATA" "$CQID"
        continue
    fi

    FROM=$(echo "$U" | jq -r '.result[0].message.chat.id // empty' 2>/dev/null)
    TEXT=$(echo "$U" | jq -r '.result[0].message.text // empty' 2>/dev/null)
    [ "$FROM" != "$CHAT_ID" ] && continue
    log "from $FROM: $TEXT"

    case "$TEXT" in
        /start|/panel|/menu) panel "$FROM" ;;
        /status)  cmd_status "$FROM" ;;
        /usage)   cmd_usage "$FROM" ;;
        /clients) cmd_clients "$FROM" ;;
        /disk)    cmd_disk "$FROM" ;;
        /hyst)    cmd_hyst "$FROM" ;;
        /link)    cmd_link "$FROM" ;;
        /approve*)
            mac=$(echo "$TEXT" | cut -d' ' -f2- | tr 'A-Z' 'a-z')
            if [ -z "$mac" ]; then
                body="Usage: /approve &lt;mac&gt; — approve a quarantined device."
            elif echo "$mac" | grep -Eq '^[0-9a-f:]{17}$'; then
                out=$(/root/quarantine.sh --approve "$mac" 2>&1)
                body="✅ ${out:-approved}"
            else
                body="Invalid MAC: <code>${mac}</code>"
            fi
            send "$FROM" "$(card "<b>🔓 Quarantine approve</b>" "$body")"
            ;;
        /quarantine*)
            act=$(echo "$TEXT" | cut -d' ' -f2-)
            case "$act" in
                on) touch /etc/quarantine-enabled; /root/quarantine.sh >/dev/null 2>&1; body="Quarantine <b>enabled</b> — new devices are blocked until approved." ;;
                off) rm -f /etc/quarantine-enabled; body="Quarantine <b>disabled</b>." ;;
                *) body="Quarantine is <b>$(/root/quarantine.sh --status)</b>." ;;
            esac
            send "$FROM" "$(card "<b>🚧 Quarantine</b>" "$body")"
            ;;
        /test*)   cmd_test "$(echo "$TEXT" | cut -d' ' -f2-)" "$FROM" ;;
        /cost)    ask_friday "$FROM" cost ;;
        /bill)    ask_friday "$FROM" bill ;;
        /balance) cmd_balance "$FROM" ;;
        /names)
            body=$(/root/usage.sh --names 2>/dev/null | while IFS='|' read -r mac name src bytes; do
                [ -z "$name" ] && continue
                printf '%s|%s|%s\n' "$name" "$src" "$bytes"
            done | dev_usage_rows)
            [ -z "$body" ] && body="No devices known yet."
            send "$FROM" "$(card "<b>📱 Known Devices</b>" "$body")"
            ;;
        /name*)
            args=$(echo "$TEXT" | cut -d' ' -f2-)
            mac=$(echo "$args" | cut -d' ' -f1)
            name=$(echo "$args" | cut -d' ' -f2-)
            if [ -z "$mac" ] || [ -z "$name" ]; then
                send "$FROM" "Usage: /name <mac or prefix> <name>   e.g. /name 96:04:e1 MyPhone"
            else
                full=$(/root/usage.sh --resolve "$mac")
                if [ -z "$full" ]; then
                    send "$FROM" "Couldn't resolve '$(esc "$mac")' to a unique device. Try /names to see devices."
                else
                    name=$(echo "$name" | tr -cd 'A-Za-z0-9 _-.' | cut -c1-24)
                    if [ -z "$name" ]; then
                        send "$FROM" "Invalid name (letters/digits/space/_- only, max 24 chars)"
                    else
                        grep -v "^$full " /etc/usage-log/user-names > /tmp/un.tmp 2>/dev/null || true
                        mv /tmp/un.tmp /etc/usage-log/user-names 2>/dev/null
                        echo "$full $name" >> /etc/usage-log/user-names
                        send "$FROM" "✅ $(esc "$full") named: <b>$(esc "$name")</b>"
                    fi
                fi
            fi
            ;;
        /unname*)
            mac=$(echo "$TEXT" | cut -d' ' -f2-)
            if [ -z "$mac" ]; then
                send "$FROM" "Usage: /unname <mac>"
            else
                full=$(/root/usage.sh --resolve "$mac")
                if [ -z "$full" ]; then
                    send "$FROM" "Couldn't resolve '$(esc "$mac")' to a unique device."
                elif grep -q "^$full " /etc/usage-log/user-names 2>/dev/null; then
                    grep -v "^$full " /etc/usage-log/user-names > /tmp/un.tmp 2>/dev/null || true
                    mv /tmp/un.tmp /etc/usage-log/user-names 2>/dev/null
                    send "$FROM" "✅ Removed custom name for $(esc "$full")"
                else
                    send "$FROM" "No custom name set for $(esc "$full")"
                fi
            fi
            ;;
        /watchlist)
            if [ -s /etc/usage-log/watchlist ]; then
                body=$( { while read -r m; do [ -n "$m" ] && printf "\n• %s" "$(/root/usage.sh --name "$m") ($m)"; done < /etc/usage-log/watchlist; } )
                send "$FROM" "$(card "<b>👀 Watched Devices</b>" "$body")"
            else
                send "$FROM" "$(card "<b>👀 Watched Devices</b>" "No watched devices.")"
            fi
            ;;
        /watch*)
            mac=$(echo "$TEXT" | cut -d' ' -f2-)
            if [ -z "$mac" ]; then
                send "$FROM" "Usage: /watch <mac or prefix>   (alert me when this device is active again)"
            else
                full=$(/root/usage.sh --resolve "$mac")
                if [ -z "$full" ]; then
                    send "$FROM" "Couldn't resolve '$(esc "$mac")' to a unique device. Try /names."
                elif grep -qx "$full" /etc/usage-log/watchlist 2>/dev/null; then
                    send "$FROM" "Already watching $(esc "$full")"
                else
                    echo "$full" >> /etc/usage-log/watchlist
                    send "$FROM" "✅ Now watching $(esc "$full") — alert on next activity"
                fi
            fi
            ;;
        /unwatch*)
            mac=$(echo "$TEXT" | cut -d' ' -f2-)
            if [ -z "$mac" ]; then
                send "$FROM" "Usage: /unwatch <mac>"
            else
                full=$(/root/usage.sh --resolve "$mac")
                if [ -z "$full" ]; then
                    send "$FROM" "Couldn't resolve '$(esc "$mac")'."
                elif grep -qx "$full" /etc/usage-log/watchlist 2>/dev/null; then
                    grep -vx "$full" /etc/usage-log/watchlist > /tmp/wl.tmp 2>/dev/null || true
                    mv /tmp/wl.tmp /etc/usage-log/watchlist 2>/dev/null
                    send "$FROM" "✅ Stopped watching $(esc "$full")"
                else
                    send "$FROM" "Not watching $(esc "$full")"
                fi
            fi
            ;;
        /friday*)
            ans=$(echo "$TEXT" | cut -d' ' -f2-)
            case "$ans" in
                yes|YES|y|Y|بله) set_friday yes; send "$FROM" "✅ Friday discount set to <b>yes</b>" ;;
                no|NO|n|N|خیر|نه) set_friday no; send "$FROM" "✅ Friday discount set to <b>no</b>" ;;
                *) send "$FROM" "Usage: /friday yes|no" ;;
            esac
            ;;
        /fridayremind*)
            ans=$(echo "$TEXT" | cut -d' ' -f2-)
            case "$ans" in
                on|ON|1|yes|Yes) sed -i "s/^FRIDAY_REMINDER=.*/FRIDAY_REMINDER=on/" /etc/billing.conf 2>/dev/null; send "$FROM" "✅ Friday reminder <b>ON</b>" ;;
                off|OFF|0|no|No) sed -i "s/^FRIDAY_REMINDER=.*/FRIDAY_REMINDER=off/" /etc/billing.conf 2>/dev/null; send "$FROM" "✅ Friday reminder <b>OFF</b>" ;;
                *) send "$FROM" "Usage: /fridayremind on|off" ;;
            esac
            ;;
        /help)
            send "$FROM" "$(card "<b>📖 Commands</b>" "/panel    — control panel (buttons)
/status   — router status
/usage    — today's usage
/cost     — today's cost
/bill     — this month's bill
/balance  — Samantel data left
/hyst     — proxy status
/clients  — connected devices
/names    — list known devices
/name     — name a device (prefix OK)
/unname   — remove custom name
/watch    — alert on activity
/unwatch  — stop watching
/watchlist— watched devices
/test     — test a URL
/disk     — storage
/friday   — set default for reports
/fridayremind — Friday reminder")" ""
            ;;
        *) send "$FROM" "Unknown command. Send /panel or /help" ;;
    esac
done
