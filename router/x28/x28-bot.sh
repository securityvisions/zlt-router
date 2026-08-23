#!/bin/sh
# x28-bot.sh — Telegram remote control for the X28 (@xirouterbot).
#
# Commands: /status /link /usage /balance /budget /outages /people /month
#   /owner /wifi /rescue /digest /bill /devices /proxy /switch_mci
#   /switch_rightel /panel /help (/start = /help + Panel)
#
# Formatting system (HTML parse mode — verified against Bot API 10.2):
#   esc()        — MANDATORY for every dynamic value (& < >)
#   card anatomy — <b>emoji Title</b> · <i>meta</i> / verdict line /
#                  rows or <pre> tables / <blockquote expandable> detail
#   4096 budget  — split_chunks() splits on newlines; failed panel edits
#                  fall back to a fresh message so data always arrives
#   transport    — every API call logs ok/error_code/description
#
# Reliability notes:
#   - instance lock via mkdir (atomic); supervisor cleans it each restart
#   - heartbeat keeper watches the parent pid and self-exits (no orphans)
#   - offset persisted AFTER handling; 600 s staleness filter absorbs replays
#   - callback taps answered immediately, stale taps skipped
#   - no `set -e`: Telegram/network errors must never kill the loop
#
# Canonical copy: router/x28/x28-bot.sh — deploys to /data/proxy/x28-bot.sh.
# Tests source this file with `$1=lib` (pure helpers, no config required).

CONF=/etc/tg.conf
STATEDIR=/tmp/x28bot
PSTATE=/data/proxy/bot-state
LOGF=$STATEDIR/hb.log
HB=$STATEDIR/hb
SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")
MCI=43211
RIGHTEL=43220
MAXMSG=4000

mkdir -p "$STATEDIR"

log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOGF"; tail -c 8192 "$LOGF" > "$LOGF.t" 2>/dev/null && mv "$LOGF.t" "$LOGF"; return 0; }
hb()  { echo $(date +%s) > "$HB.w"; mv "$HB.w" "$HB"; }

load_conf() {
    . "$CONF" 2>/dev/null || { log "bot: cannot load $CONF"; return 1; }
    [ -n "${TOKEN:-}" ] || { log "bot: TOKEN missing"; return 1; }
    case "${CHAT_ID:-}" in ""|__*|0) log "bot: CHAT_ID missing"; return 1 ;; esac
    API="https://api.telegram.org/bot$TOKEN"
    PROXY="${PROXY:-socks5h://192.168.70.1:1080}"
    JQ="${JQ_BIN:-/data/proxy/jq}"
    [ -x "$JQ" ] || JQ=$(command -v jq 2>/dev/null || true)
    [ -n "${JQ:-}" ] || { log "bot: FATAL jq unavailable"; return 1; }
    return 0
}

load_conf_or_die() {
    load_conf || exit 1
    # jq is the bot's nervous system — degrade loudly instead of zombie-looping
    if [ ! -x "$JQ" ]; then
        log "bot: FATAL jq missing at $JQ"
        timeout 10 curl -s -m 8 -x "$PROXY" "$API/sendMessage" \
            --data-urlencode "chat_id=$CHAT_ID" \
            --data-urlencode "text=⚠️ bot degraded: jq missing — commands disabled until restored" >/dev/null 2>&1 || true
        exit 1
    fi
}

# ---------- formatting helpers ----------
esc() { printf '%s' "$1" | sed -e 's/&/\&amp;/g' -e 's/</\&lt;/g' -e 's/>/\&gt;/g'; }

# split_chunks <text> — pieces ≤ MAXMSG chars, preferring newline boundaries.
split_chunks() {
    printf '%s\n' "${1:-}" | awk -v max="$MAXMSG" '
    {
        line = $0 "\n"
        while (length(line) > max) { print substr(line, 1, max); line = substr(line, max+1) }
        if (length(buf) + length(line) > max) { printf "%s", buf; buf = "" }
        buf = buf line
    }
    END { sub(/\n$/, "", buf); printf "%s", buf }' | grep -v '^$' || printf '%s' "${1:-}" | head -c "$MAXMSG"
}

verdict_emoji() {
    case "$1" in
        *GREEN*) echo "✅ $1" ;;
        *RED*)   echo "❌ $1" ;;
        *)       echo "⚠️ ${1:-unknown}" ;;
    esac
}
safe_arg() {
    case "${1:-}" in "") return 1 ;; *[!A-Za-z0-9_.:-]*) return 1 ;; esac
    printf '%s' "$1"
}
now_hm() { date '+%H:%M' 2>/dev/null; }

# join_chunks <text> - <=MAXMSG pieces joined by the sentinel "[[C]]".
# Pieces land in a temp file first so every awk has an explicit input file
# (deep $( ) nesting + inherited stdin caused a rare pipe hang).
join_chunks() {
    _jf=$(mktemp) || return 1
    split_chunks "${1:-}" > "$_jf"
    awk -v max="$MAXMSG" -v sep="[[C]]" '
    {
        piece = $0 "\n"
        if (length(buf) > 0 && length(buf) + length(piece) > max) { printf "%s%s", buf, sep; buf = "" }
        buf = buf piece
    }
    END { sub(/\n$/, "", buf); printf "%s", buf }' "$_jf"
    rm -f "$_jf"
}
# ---------- telegram transport ----------
tg_post() {  # tg_post <method> <args…> — response-aware logging
    _m="$1"; shift
    _resp=$(timeout 20 curl -s -m 18 -x "$PROXY" "$API/$_m" "$@" 2>/dev/null)
    _ok=$(printf '%s' "$_resp" | "$JQ" -r '.ok // "false"' 2>/dev/null)
    if [ "$_ok" != "true" ]; then
        _code=$(printf '%s' "$_resp" | "$JQ" -r '.error_code // "-"' 2>/dev/null)
        _desc=$(printf '%s' "$_resp" | "$JQ" -r '.description // "empty response"' 2>/dev/null)
        log "tg: $_m FAILED ($_code) $_desc"
    fi
    printf '%s' "$_resp"
}

send_one() {  # send_one <html-text> — exactly one sendMessage call
    tg_post sendMessage \
        --data-urlencode "chat_id=${CHAT_ID:-}" \
        --data-urlencode "text=$1" \
        --data-urlencode "parse_mode=HTML"         --data-urlencode 'link_preview_options={"is_disabled":true}' >/dev/null 2>&1 || true
}

html_send() {  # html_send <html-text>
    rest=$(join_chunks "${1:-}")
    while [ -n "$rest" ]; do
        case "$rest" in
            *"[[C]]"*) part=${rest%%"[[C]]"*}; rest=${rest#*"[[C]]"} ;;
            *)         part=$rest;             rest="" ;;
        esac
        [ -n "$part" ] && send_one "$part"
    done
}

edit_html() {  # edit_html <mid> <html-text> — edit in place, fall back to send
    _mid="$1"
    rest=$(join_chunks "$2")
    while [ -n "$rest" ]; do
        case "$rest" in
            *"[[C]]"*) part=${rest%%"[[C]]"*}; rest=${rest#*"[[C]]"} ;;
            *)         part=$rest;             rest="" ;;
        esac
        [ -n "$part" ] || continue
        _resp=$(tg_post editMessageText             --data-urlencode "chat_id=${CHAT_ID:-}"             --data-urlencode "message_id=$_mid"             --data-urlencode "text=$part"             --data-urlencode "parse_mode=HTML"             --data-urlencode 'link_preview_options={"is_disabled":true}')
        _ok=$(printf '%s' "$_resp" | "$JQ" -r '.ok // "false"' 2>/dev/null)
        if [ "$_ok" != "true" ]; then
            _desc=$(printf '%s' "$_resp" | "$JQ" -r '.description // ""' 2>/dev/null)
            case "$_desc" in *"not modified"*) : ;; *) html_send "$part" ;; esac
        fi
    done
}

answer_cbq() {
    timeout 10 curl -s -m 8 -x "$PROXY" "$API/answerCallbackQuery" \
        --data-urlencode "callback_query_id=$1" \
        ${2:+--data-urlencode "text=$2"} >/dev/null 2>&1 || true
}

send_photo() {
    [ -f "$1" ] || return 1
    timeout 30 curl -s -m 25 -x "$PROXY" "$API/sendPhoto" \
        -F "chat_id=${CHAT_ID:-}" -F "photo=@$1" -F "caption=$2" \
        -F "parse_mode=HTML" >/dev/null 2>&1 || true
}

panel_keyboard() {
    printf '%s' '{"inline_keyboard":[
 [{"text":"📊 Status","callback_data":"panel:status"},{"text":"📶 Link","callback_data":"panel:link"}],
 [{"text":"💾 Usage","callback_data":"panel:usage"},{"text":"💰 Balance","callback_data":"panel:balance"}],
 [{"text":"📱 Devices","callback_data":"panel:devices"},{"text":"🧾 Bill","callback_data":"panel:bill"}],
 [{"text":"🛰️ Proxy","callback_data":"panel:proxy"},{"text":"❓ Help","callback_data":"panel:help"}],
 [{"text":"💰 Budget","callback_data":"panel:budget"},{"text":"📉 Outages","callback_data":"panel:outages"}],
 [{"text":"👥 People","callback_data":"panel:people"},{"text":"📶 WiFi","callback_data":"panel:wifi"}]]}'
}

send_panel() {
    _kb=$(panel_keyboard)
    _body="<b>🎛 X28 Panel</b> · $(now_hm)
$(fmt_status)"
    _resp=$(timeout 20 curl -s -m 18 -x "$PROXY" "$API/sendMessage" \
        --data-urlencode "chat_id=${CHAT_ID:-}" \
        --data-urlencode "text=$_body" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode "reply_markup=$_kb" \
        --data-urlencode 'link_preview_options={"is_disabled":true}' 2>/dev/null)
    _mid=$(printf '%s' "$_resp" | "$JQ" -r '.result.message_id // ""' 2>/dev/null)
    [ -n "$_mid" ] && echo "$_mid" > "$STATEDIR/panel_msg_id"
}

edit_panel() {
    _kb=$(panel_keyboard)
    _resp=$(timeout 20 curl -s -m 18 -x "$PROXY" "$API/editMessageText" \
        --data-urlencode "chat_id=${CHAT_ID:-}" \
        --data-urlencode "message_id=$1" \
        --data-urlencode "text=$2" \
        --data-urlencode "parse_mode=HTML" \
        --data-urlencode "reply_markup=$_kb" \
        --data-urlencode 'link_preview_options={"is_disabled":true}' 2>/dev/null)
    _ok=$(printf '%s' "$_resp" | "$JQ" -r '.ok // "false"' 2>/dev/null)
    if [ "$_ok" != "true" ]; then
        _desc=$(printf '%s' "$_resp" | "$JQ" -r '.description // ""' 2>/dev/null)
        case "$_desc" in *"not modified"*) : ;; *) html_send "$2" ;; esac
    fi
}

# ---------- data plumbing ----------
data_ok() {
    code=$(curl -k -s -m 8 -o /dev/null -w '%{http_code}' https://1.1.1.1 2>/dev/null)
    case "$code" in 200|204|301|302) return 0 ;; esac
    return 1
}
cur_plmn() {
    timeout 20 sh /data/proxy/linkstate.sh 2>/dev/null | sed -n 's/^plmn=//p' | head -1
}
do_switch() {
    target="$1" name="$2"
    cur=$(cur_plmn)
    if [ "$cur" = "$target" ] && data_ok; then
        html_send "🔄 <b>Already on $name</b>
Data confirmed healthy — no switch needed."
        return 0
    fi
    html_send "🔄 <b>Switching to $name…</b>
<i>This takes up to ~3 minutes. I'll report back automatically.</i>"
    BOTPID=$$
    ( while :; do kill -0 "$BOTPID" 2>/dev/null || exit 0; hb; sleep 15; done ) &
    keeper=$!
    timeout 300 sh /data/proxy/operator-watchdog.sh switch "$target" >/dev/null 2>&1
    rc=$?
    kill "$keeper" 2>/dev/null
    hb
    tail2=$(tail -n 2 /data/proxy/watchdog.log 2>/dev/null | esc)
    st=$(sh /data/proxy/x28-status.sh 2>/dev/null | head -5 | esc)
    if [ "$rc" = "0" ]; then
        html_send "✅ <b>Switch to $name complete</b> · $(now_hm)
Data confirmed on the new operator.

<pre>$st</pre>"
    else
        html_send "❌ <b>Switch to $name not confirmed</b>
<pre>$tail2</pre>
Check <code>/status</code> — the watchdog keeps monitoring."
    fi
    return 0
}

# ---------- formatters (input-seamed for tests) ----------
fmt_status() {  # fmt_status [status_output]
    local out="${1:-}"
    [ -z "$out" ] && out=$(sh /data/proxy/x28-status.sh 2>/dev/null)
    [ -z "$out" ] && { echo "⚠️ status unavailable — try again shortly"; return; }
    printf '%s\n' "$out" | awk '
    {
        key = $1; val = substr($0, length(key) + 2)
        gsub(/_/, " ", key)
        icon=""
        if(key=="operator")icon="📡"; else if(key=="signal")icon="📶"
        else if(key=="data")icon="🌐"; else if(key=="proxy")icon="🛰️"
        else if(key=="devices")icon="📱"; else if(key=="uptime")icon="⏱"
        else if(key=="ram")icon="🧠"; else if(key=="temp")icon="🌡️"
        else if(key=="services")icon="⚙️"
        printf "%s %s\n", icon, $0
    }'
}

fmt_devices() {  # fmt_devices [leases_file]
    local f="${1:-/tmp/dnsmasq.leases}"
    [ -f "$f" ] || { echo "No DHCP leases yet."; return; }
    awk '
    {
        mac=$2; ip=$3; host=$4
        if(host=="*"||host=="") host="?"
        c=substr(mac,2,1); rnd=(c~/[26aeAE]/)?1:0
        tag=rnd?" 🎲":""
        printf "%-14s %-15s %s%s\n", host, ip, mac, tag
    }' "$f" | sort
}

bal_card() {  # bal_card [pre-fetched report]
    local out ts age mins
    out="${1:-}"
    [ -z "$out" ] && out=$(sh /root/balance.sh --report 2>/dev/null)
    case "$out" in
        *"GB left across"*) printf '%s\n' "$out" ;;
        *)
            if [ -f /tmp/balance_report ] && grep -q "GB left across" /tmp/balance_report 2>/dev/null; then
                ts=$(cat /tmp/balance_report.ts 2>/dev/null || echo 0)
                age=$(( $(date +%s) - ${ts:-0} )); [ "$age" -lt 0 ] && age=0
                printf '%s\n<i>cached ~%d min ago — live query failed</i>\n' \
                    "$(cat /tmp/balance_report 2>/dev/null)" $(( age / 60 ))
            else
                printf '%s\n' "$out"
            fi
            ;;
    esac
}

help_text() {
    cat <<'EOF'
<b>🤖 X28 Bot</b>

<b>Network</b>
/status overview · /link signal detail
/proxy tunnel state · /devices who's online

<b>Data</b>
/balance Samantel left · /usage today
/bill week + cost · /budget forecast

<b>Reports</b>
/outages SLA ledger · /people per-person month
/month any Jalali month · /digest weekly story

<b>Household</b>
/wifi guest QR · /owner assign device→person

<b>Control</b>
/switch_mci · /switch_rightel
/rescue collected-node failover

Everything lives in the Panel too: /panel
EOF
}


# html_send_owner_panel — Owner Panel Card with inline keyboard for tap-to-assign.
html_send_owner_panel() {
    local owners_f="/data/proxy/owners.conf"
    local leases="/tmp/dnsmasq.leases"
    local kb='{"inline_keyboard":['
    local first=1 row=""
    local unassigned="" p pcount

    # collect persons and their device counts from owners.conf
    declare -A persons
    if [ -f "$owners_f" ]; then
        while IFS='|' read -r mac person; do
            [ -z "$mac" ] && continue
            persons[$person]=$(( ${persons[$person]:-0} + 1 ))
        done < "$owners_f"
    fi

    # find unassigned devices: leases whose MAC is not in owners.conf
    if [ -f "$leases" ]; then
        while IFS=' ' read -r _ _ mac host; do
            [ -z "$mac" ] && continue
            assigned=0
            if [ -f "$owners_f" ]; then
                grep -qiF "^$mac|" "$owners_f" 2>/dev/null && assigned=1
            fi
            if [ "$assigned" = "0" ]; then
                unassigned="$unassigned{"text":"$host","callback_data":"ownd:$mac"},"
            fi
        done < "$leases"
    fi

    # unassigned device buttons (one per row, up to 4)
    if [ -n "$unassigned" ]; then
        local old_ifs=$IFS; IFS=','
        for btn in $unassigned; do
            [ -n "$btn" ] || continue
            [ "$first" = "0" ] && kb="$kb,"
            kb="$kb[$btn]"; first=0
        done
        IFS=$old_ifs
    fi

    # person buttons (two per row): own:p:<b64(name)>
    if [ -f "$owners_f" ]; then
        row=""
        for p in "${!persons[@]}"; do
            b64=$(printf '%s' "$p" | base64 -w0 2>/dev/null || printf '%s' "$p")
            btn="{\"text\":\"$p (${persons[$p]})\",\"callback_data\":\"ownp:$b64\"}"
            if [ -z "$row" ]; then row="$btn"
            else kb="$kb,[$row,$btn]"; row=""; first=0
            fi
        done
        [ -n "$row" ] && { [ "$first" = "0" ] && kb="$kb,"; kb="$kb[$row]"; first=0; }
    fi

    # utility row
    [ "$first" = "0" ] && kb="$kb,"
    kb="${kb}[{"text":"📋 List all","callback_data":"ownl:x"},{"text":"🔄 Refresh","callback_data":"ownr:x"}]]}"

    local body="<b>👤 Owners</b> · $(now_hm)"
    if [ -n "$unassigned" ]; then
        body="$body
⚠️ Tap an unassigned device above to assign it."
    fi

    timeout 20 curl -s -m 18 -x "$PROXY" "$API/sendMessage"         --data-urlencode "chat_id=${CHAT_ID:-}"         --data-urlencode "text=$body"         --data-urlencode "parse_mode=HTML"         --data-urlencode "reply_markup=$kb"         --data-urlencode 'link_preview_options={"is_disabled":true}' >/dev/null 2>&1 || true
}

# ---- bot mode ----
bot() {
    load_conf_or_die
    # instance lock: atomic mkdir; supervisor cleans it between restarts
    if ! mkdir "$STATEDIR/lock" 2>/dev/null; then
        log "bot: another instance holds the lock — exiting"
        exit 1
    fi

    oldpid=$(cat "$STATEDIR/bot.pid" 2>/dev/null)
    if [ -n "$oldpid" ] && [ "$oldpid" != "$$" ] && kill -0 "$oldpid" 2>/dev/null; then
        log "bot: already running (pid $oldpid)"
        rmdir "$STATEDIR/lock" 2>/dev/null
        exit 1
    fi
    echo $$ > "$STATEDIR/bot.pid"
    hb
    log "bot: started pid=$$"

    mkdir -p "$PSTATE"
    off=$(cat "$PSTATE/offset" 2>/dev/null || echo 0)
    while :; do
        hb
        resp=$(curl -s -m 60 -x "$PROXY" "$API/getUpdates?timeout=50&offset=$off" 2>/dev/null)
        ok=$(printf '%s' "$resp" | "$JQ" -r '.ok // "false"' 2>/dev/null)
        if [ "$ok" != "true" ]; then
            code=$(printf '%s' "$resp" | "$JQ" -r '.error_code // ""' 2>/dev/null)
            desc=$(printf '%s' "$resp" | "$JQ" -r '.description // "network/empty"' 2>/dev/null)
            case "$code" in
                409) log "poll: 409 conflict — another poller likely active" ;;
                401) log "poll: 401 unauthorized — TOKEN invalid; backing off hard"; sleep 300 ;;
                *)   log "poll: $code $desc"; sleep 10 ;;
            esac
            continue
        fi
        n=$(printf '%s' "$resp" | "$JQ" '.result | length' 2>/dev/null)
        [ -z "$n" ] && { sleep 10; continue; }
        i=0
        while [ "$i" -lt "$n" ]; do
            uid=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].update_id" 2>/dev/null)
            cid=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].message.chat.id // \"\"" 2>/dev/null)
            text=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].message.text // \"\"" 2>/dev/null)
            mdate=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].message.date // \"\"" 2>/dev/null)
            cbid=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].callback_query.id // \"\"" 2>/dev/null)
            cbdata=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].callback_query.data // \"\"" 2>/dev/null)
            cbcid=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].callback_query.message.chat.id // \"\"" 2>/dev/null)
            cbmid=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].callback_query.message.message_id // \"\"" 2>/dev/null)
            cbdate=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].callback_query.message.date // \"\"" 2>/dev/null)
            hb

            if [ "$cbcid" = "$CHAT_ID" ] && [ -n "$cbdata" ]; then
                # instant ack, then staleness guard, then dispatch
                answer_cbq "$cbid"
                action=${cbdata#panel:}
                if [ -n "$cbdate" ] && [ $(( $(date +%s) - cbdate )) -gt 600 ]; then
                    log "cb: skipped stale tap=$action (age $(( $(date +%s) - cbdate ))s)"
                else
                    log "cb: tap=$action"
                    case "$action" in
                        status)  body="<b>📊 Status</b> · $(now_hm)
$(esc "$(fmt_status)")" ;;
                        link)    body="<b>📶 Link detail</b> · $(now_hm)
<blockquote expandable>$(esc "$(timeout 20 sh /data/proxy/linkstate.sh 2>/dev/null)")</blockquote>" ;;
                        usage)   body="<b>💾 Usage today</b>
<pre>$(esc "$(sh /data/proxy/usage/x28-usage.sh today 2>/dev/null)")</pre>" ;;
                        balance) body="<b>💰 Balance</b> · $(now_hm)
$(esc "$(bal_card | head -12)")" ;;
                        devices) body="<b>📱 Devices</b>
<pre>$(esc "$(fmt_devices)")</pre>" ;;
                        bill)    body="<b>🧾 Weekly bill</b>
<pre>$(esc "$(sh /data/proxy/usage/x28-usage.sh week 2>/dev/null)")</pre>" ;;
                        proxy)   body="<b>🛰️ Proxy</b> · $(now_hm)
active : <code>$(curl -s -m 5 http://127.0.0.1:9090/proxies/auto 2>/dev/null | grep -o '"now":"[^"]*"' | cut -d'"' -f4)</code>
health : $(verdict_emoji "$(sh /data/proxy/x28-health.sh 2>/dev/null | tail -1)")
rescue : $(sh /data/proxy/x28-rescue.sh status 2>/dev/null | tr '\n' ' ')" ;;
                        budget)  body="<b>💰 Budget</b>
$(esc "$(sh /data/proxy/x28-budget.sh --card 2>/dev/null)")" ;;
                        outages) body="<b>📉 Outages</b>
$(esc "$(sh /data/proxy/x28-outage-ledger.sh report 2>/dev/null)")" ;;
                        digest)  body="$(esc "$(sh /data/proxy/x28-digest.sh 2>/dev/null)")" ;;
                        people)  body="$(esc "$(sh /data/proxy/x28-people.sh 2>/dev/null)")" ;;
                        wifi)
                            if path=$(sh /data/proxy/x28-wifi.sh qr 2>/dev/null); then
                                cap=$(sh /data/proxy/x28-wifi.sh card 2>/dev/null | head -n 3 | esc)
                                send_photo "$path" "$cap" || html_send "$(esc "$(sh /data/proxy/x28-wifi.sh card 2>/dev/null)")"
                            else
                                html_send "$(sh /data/proxy/x28-wifi.sh card 2>/dev/null)"
                            fi
                            body="" ;;
                        ledg:*)
                            lf=${action#ledg:}
                            if [ -f "$lf" ]; then body=$(cat "$lf"); else body="page not found"; fi ;;
                        ownd:*)
                            mac=${action#ownd:}
                            body="<b>👤 Assign device</b>
Device: <code>$(esc "$mac")</code>

Reply with: <code>/owner assign $mac &lt;name&gt;</code>"
                            kb='{"inline_keyboard":[[{"text":"⬜ Unassigned","callback_data":"ownu:'"$mac"'"}]]}'
                            answer_cbq "$cbid"
                            timeout 20 curl -s -m 18 -x "$PROXY" "$API/sendMessage"                                 --data-urlencode "chat_id=$CHAT_ID"                                 --data-urlencode "text=$body"                                 --data-urlencode "parse_mode=HTML"                                 --data-urlencode "reply_markup=$kb" >/dev/null 2>&1 || true
                            body="" ;;
                        ownp:*)
                            pname=$(printf '%s' "${action#ownp:}" | base64 -d 2>/dev/null)
                            body="<b>👤 $pname's devices</b> · $(now_hm)
$(grep -i "|$pname\$" /data/proxy/owners.conf 2>/dev/null | while IFS='|' read -r mac person; do
    host=$(grep "$mac" /tmp/dnsmasq.leases 2>/dev/null | awk '{print \$4}')
    printf '• %s <code>%s</code>\n' "\${host:-?}" "\$mac"
done)" ;;
                        ownl:*) body="<b>👤 All assignments</b>
\$(sh /data/proxy/x28-owners.sh list 2>/dev/null | esc)" ;;
                        ownr:*) html_send_owner_panel; body="" ;;
                        help)    body="$(help_text)" ;;
                        panel|start) body="$(help_text)" ;;
                        *)       body="unknown tap" ;;
                    esac
                    [ -n "$cbmid" ] && edit_panel "$cbmid" "$body"
                fi
            elif [ "$cid" = "$CHAT_ID" ] && [ -n "$text" ]; then
                if [ -n "$mdate" ] && [ $(( $(date +%s) - mdate )) -gt 600 ]; then
                    log "cmd: skipped stale update uid=$uid"
                else
                cmd=$(printf '%s' "$text" | awk '{print $1}')
                log "cmd: $cmd"
                case "$cmd" in
                    /start|/help) html_send "$(help_text)"; send_panel ;;
                    /panel)       send_panel ;;
                    /status)
                        hv=$(sh /data/proxy/x28-health.sh 2>/dev/null | tail -1)
                        html_send "<b>📊 Status</b> · $(now_hm)
$(verdict_emoji "$hv")

$(esc "$(fmt_status)")" ;;
                    /link)
                        html_send "<b>📶 Link detail</b> · $(now_hm)
<blockquote expandable>$(esc "$(timeout 20 sh /data/proxy/linkstate.sh 2>/dev/null)")</blockquote>" ;;
                    /usage)
                        html_send "<b>💾 Usage today</b>
<pre>$(esc "$(sh /data/proxy/usage/x28-usage.sh today 2>/dev/null)")</pre>" ;;
                    /bill)
                        html_send "<b>🧾 Weekly bill</b>
<pre>$(esc "$(sh /data/proxy/usage/x28-usage.sh week 2>/dev/null)")</pre>" ;;
                    /balance)
                        html_send "<b>💰 Balance</b> · $(now_hm)
$(esc "$(bal_card | head -20)")" ;;
                    /devices)
                        html_send "<b>📱 Devices</b>
<pre>$(esc "$(fmt_devices)")</pre>" ;;
                    /proxy)
                        html_send "<b>🛰️ Proxy</b> · $(now_hm)
active : <code>$(curl -s -m 5 http://127.0.0.1:9090/proxies/auto 2>/dev/null | grep -o '"now":"[^"]*"' | cut -d'"' -f4)</code>
health : $(verdict_emoji "$(sh /data/proxy/x28-health.sh 2>/dev/null | tail -1)")
rescue : $(sh /data/proxy/x28-rescue.sh status 2>/dev/null | tr '\n' ' ')" ;;
                    /budget)
                        html_send "<b>💰 Budget</b>
$(esc "$(sh /data/proxy/x28-budget.sh --card 2>/dev/null)")" ;;
                    /outages)
                        arg=$(safe_arg "$(printf '%s' "$text" | awk '{print $2}')")
                        html_send "<b>📉 Outages</b>
$(esc "$(sh /data/proxy/x28-outage-ledger.sh report $arg 2>/dev/null)")" ;;
                    /people|/month)
                        arg=$(safe_arg "$(printf '%s' "$text" | awk '{print $2}')")
                        html_send "$(sh /data/proxy/x28-people.sh $arg 2>/dev/null)" ;;
                    /owner)
                        sub=$(printf '%s' "$text" | awk '{print $2}')
                        rest=$(printf '%s' "$text" | cut -s -d' ' -f3-)
                        case "$sub" in
                            assign)
                                mac=$(safe_arg "$(printf '%s' "$rest" | awk '{print $1}')")
                                person=$(printf '%s' "$rest" | cut -s -d' ' -f2-)
                                [ -n "$mac" ] || { html_send "👤 Usage: <code>/owner assign &lt;mac|hostname&gt; &lt;name&gt;</code>"; continue; }
                                out=$(sh /data/proxy/x28-owners.sh assign "$mac" "$person" 2>&1 | esc) ;;
                            unassign)
                                mac=$(safe_arg "$(printf '%s' "$rest" | awk '{print $1}')")
                                out=$(sh /data/proxy/x28-owners.sh unassign "$mac" 2>&1 | esc) ;;
                            rename)
                                old_n=$(safe_arg "$(printf '%s' "$text" | awk '{print $3}')")
                                new_n=$(printf '%s' "$text" | cut -s -d' ' -f4-)
                                out=$(sh /data/proxy/x28-owners.sh rename "$old_n" "$new_n" 2>&1 | esc) ;;
                            list|"")
                                html_send_owner_panel ;;
                            *) out=$(sh /data/proxy/x28-owners.sh "$sub" $(printf '%s' "$text" | cut -s -d' ' -f2-) 2>&1 | esc) ;;
                        esac
                        case "$sub" in
                            assign|unassign|rename|"") : ;; # panel/confirmation already sent or handled
                            *) html_send "👤 Owner
$out" ;;
                        esac ;;
                    /wifi)
                        if path=$(sh /data/proxy/x28-wifi.sh qr 2>/dev/null); then
                            cap=$(sh /data/proxy/x28-wifi.sh card 2>/dev/null | head -n 3 | esc)
                            send_photo "$path" "$cap" || html_send "$(esc "$(sh /data/proxy/x28-wifi.sh card 2>/dev/null)")"
                        else
                            html_send "$(sh /data/proxy/x28-wifi.sh card 2>/dev/null)"
                        fi
                        ;;
                    /rescue)
                        rarg=$(safe_arg "$(printf '%s' "$text" | awk '{print $2}')")
                        case "$rarg" in
                            on|off) sh /data/proxy/x28-rescue.sh switch "$rarg" >/dev/null 2>&1 ;;
                            *)      rarg="" ;;
                        esac
                        html_send "🛟 Rescue · $(now_hm)
$(esc "$(sh /data/proxy/x28-rescue.sh status 2>/dev/null)")$( [ -n "$rarg" ] && printf '\n<i>switched: %s</i>' "$rarg" )" ;;
                    /digest)
                        html_send "$(sh /data/proxy/x28-digest.sh 2>/dev/null)" ;;
                    /ledger)
                        ldir="/data/proxy/usage/ledger"
                        if [ -d "$ldir" ] && ls "$ldir"/J-*.txt >/dev/null 2>&1; then
                            kb='{"inline_keyboard":['
                            first=1
                            for f in $(ls -1r "$ldir"/J-*.txt 2>/dev/null | head -12); do
                                jm=$(basename "$f" .txt); [ "$first" = "0" ] && kb="$kb,"
                                kb="$kb[{"text":"$jm","callback_data":"ledg:$f"}]"; first=0
                            done; kb="$kb]}"
                            timeout 20 curl -s -m 18 -x "$PROXY" "$API/sendMessage" \
                                --data-urlencode "chat_id=$CHAT_ID" \
                                --data-urlencode "text=📜 <b>Frozen Ledger pages</b> — tap to view" \
                                --data-urlencode "parse_mode=HTML" \
                                --data-urlencode "reply_markup=$kb" >/dev/null 2>&1 || true
                        else
                            html_send "📜 <b>Ledger</b> — no frozen pages yet (first appears after next Jalali month-end)"
                        fi ;;
                    /switch_mci)     do_switch "$MCI" "MCI" ;;
                    /switch_rightel) do_switch "$RIGHTEL" "Rightel" ;;
                    *) html_send "❓ Unknown command — <code>/help</code> lists everything." ;;
                esac
                fi
            elif [ -n "$cid" ] && [ "$cid" != "$CHAT_ID" ]; then
                log "ignored update from chat $cid"
            fi
            # offset persisted AFTER successful handling; staleness filters replay
            off=$((uid + 1)); echo "$off" > "$PSTATE/offset"
            i=$((i + 1))
        done
    done
}

supervise() {
    load_conf >/dev/null 2>&1 || true
    while :; do
        rm -rf "$STATEDIR/lock"
        sh "$SELF" bot >> "$LOGF" 2>&1 &
        bpid=$!
        log "supervisor: bot started pid=$bpid"
        culled=0
        while kill -0 "$bpid" 2>/dev/null; do
            sleep 20
            [ "$culled" = "1" ] && break
            hbv=$(cat "$HB" 2>/dev/null || echo 0)
            if [ -z "$hbv" ]; then sleep 5; continue; fi
            now=$(date +%s)
            if [ $((now - hbv)) -gt 180 ]; then
                log "supervisor: bot pid=$bpid WEDGED (hb age $((now-hbv))s), killing"
                kill -9 "$bpid" 2>/dev/null
                culled=1
            fi
        done
        wait "$bpid" 2>/dev/null
        rm -f "$STATEDIR/bot.pid"
        rm -rf "$STATEDIR/lock"
        log "supervisor: bot gone, restarting in 5s"
        sleep 5
    done
}

case "${BOT_MODE:-${1:-supervise}}" in
    lib)       : ;;                       # sourced for tests — define only
    bot)       load_conf_or_die; bot ;;
    supervise) supervise ;;
    *)         echo "usage: x28-bot.sh [bot|supervise|lib]"; exit 2 ;;
esac
