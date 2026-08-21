#!/bin/sh
# x28-bot.sh — Telegram remote control for the X28 (@xirouterbot).
#
# Commands (only from the allowlisted chat in /etc/tg.conf):
#   /status /link /usage /balance /budget /digest /bill /devices /proxy
#   /switch_mci /switch_rightel /panel /help (/start = /help + Panel)
#
# Design notes:
#   - Operator switching goes ONLY through operator-watchdog.sh's one-shot
#     "switch" mode: the same proven vendor select (cmd 228) the web UI
#     uses, plus the shared storm guard, dns-fix re-apply and data
#     confirmation. The PLMN lock (cmd 219) that once wedged this modem
#     appears nowhere.
#   - Long-poll loop (timeout=50s); heartbeat file written every cycle and
#     kept fresh by a keeper during long switches, so the supervisor can
#     cull a wedged bot without false-positive mid-switch kills.
#   - No `set -e`: Telegram/network errors must never kill the loop.
#   - Device identity is hostname-first: phones with randomized MACs rotate
#     addresses, so the stable name (DHCP hostname or user alias) wins and
#     the MAC is shown as secondary info only.
#
# Canonical copy: router/x28/x28-bot.sh — deploys to /data/proxy/x28-bot.sh.
# Service: /etc/init.d/x28-bot runs `x28-bot.sh supervise` under procd.

CONF=/etc/tg.conf
. "$CONF" 2>/dev/null || exit 1
[ -n "${TOKEN:-}" ] || exit 1
case "${CHAT_ID:-}" in ""|__*|0) exit 1 ;; esac

JQ=/data/proxy/jq
API="https://api.telegram.org/bot$TOKEN"
PROXY="socks5h://192.168.70.1:1080"
STATEDIR=/tmp/x28bot
PSTATE=/data/proxy/bot-state   # persists reboots — see offset note below
LOGF=$STATEDIR/hb.log
HB=$STATEDIR/hb
SELF=$(cd "$(dirname "$0")" && pwd)/$(basename "$0")

MCI=43211
RIGHTEL=43220

mkdir -p "$STATEDIR"
log() { echo "$(date '+%Y-%m-%d %H:%M:%S') $*" >> "$LOGF"; tail -c 8192 "$LOGF" > "$LOGF.t" 2>/dev/null && mv "$LOGF.t" "$LOGF"; return 0; }
# hb — atomic heartbeat write (tmp+mv): the supervisor must never read a
# half-written file and mistake it for a stale one (race that once culled a
# healthy bot mid-switch).
hb()  { echo $(date +%s) > "$HB.w"; mv "$HB.w" "$HB"; }

# send <text> — reply to the allowlisted chat (best-effort).
send() {
    timeout 20 curl -s -m 18 -x "$PROXY" "$API/sendMessage" \
        --data-urlencode "chat_id=$CHAT_ID" \
        --data-urlencode "text=$1" >/dev/null 2>&1 || true
}

# panel_keyboard — the 4×2 Panel grid (bot-wonderful 01). callback_data
# carries "panel:<action>" so the tap handler dispatches without parsing text.
panel_keyboard() {
    printf '%s' '{"inline_keyboard":[
 [{"text":"📊 Status","callback_data":"panel:status"},{"text":"📶 Link","callback_data":"panel:link"}],
 [{"text":"💾 Usage","callback_data":"panel:usage"},{"text":"💰 Balance","callback_data":"panel:balance"}],
 [{"text":"📱 Devices","callback_data":"panel:devices"},{"text":"🧾 Bill","callback_data":"panel:bill"}],
 [{"text":"🛰️ Proxy","callback_data":"panel:proxy"},{"text":"❓ Help","callback_data":"panel:help"}],
 [{"text":"💰 Budget","callback_data":"panel:budget"},{"text":"🧾 Digest","callback_data":"panel:digest"}]]}'
}

# send_panel — post the Panel message (keyboard + welcome body); stores message_id.
send_panel() {
    local resp mid kb
    kb=$(panel_keyboard)
    resp=$(timeout 20 curl -s -m 18 -x "$PROXY" "$API/sendMessage" \
        --data-urlencode "chat_id=$CHAT_ID" \
        --data-urlencode "text=X28 Panel — tap a button:
──────────────
$(sh /data/proxy/x28-status.sh 2>/dev/null | head -5)" \
        --data-urlencode "reply_markup=$kb" 2>/dev/null)
    mid=$(printf '%s' "$resp" | "$JQ" -r '.result.message_id // ""' 2>/dev/null)
    [ -n "$mid" ] && echo "$mid" > "$STATEDIR/panel_msg_id"
}

# answer_cbq <callback_query_id> [text] — acknowledge a tap (stops the spinner).
answer_cbq() {
    timeout 10 curl -s -m 8 -x "$PROXY" "$API/answerCallbackQuery" \
        --data-urlencode "callback_query_id=$1" \
        ${2:+--data-urlencode "text=$2"} >/dev/null 2>&1 || true
}

# edit_panel <message_id> <text> — edit the Panel message in place, keyboard stays.
edit_panel() {
    local kb
    kb=$(panel_keyboard)
    timeout 20 curl -s -m 18 -x "$PROXY" "$API/editMessageText" \
        --data-urlencode "chat_id=$CHAT_ID" \
        --data-urlencode "message_id=$1" \
        --data-urlencode "text=$2" \
        --data-urlencode "reply_markup=$kb" >/dev/null 2>&1 || true
}

# data_ok — same probe the watchdog uses (HTTPS by IP, no DNS).
data_ok() {
    code=$(curl -k -s -m 8 -o /dev/null -w '%{http_code}' https://1.1.1.1 2>/dev/null)
    case "$code" in 200|204|301|302) return 0 ;; esac
    return 1
}

# cur_plmn — live PLMN via the link reader.
cur_plmn() {
    timeout 20 sh /data/proxy/linkstate.sh 2>/dev/null | sed -n 's/^plmn=//p' | head -1
}

# do_switch <plmn> <name> — storm-guarded switch via the watchdog one-shot,
# heartbeat kept fresh while it runs (reselect + confirm can take ~3 min).
do_switch() {
    target="$1" name="$2"
    cur=$(cur_plmn)
    if [ "$cur" = "$target" ] && data_ok; then
        send "Already on $name — data OK. No switch needed."
        return 0
    fi
    send "Switching to $name … can take up to ~3 min. Will report back."
    ( while :; do hb; sleep 15; done ) &
    keeper=$!
    timeout 300 sh /data/proxy/operator-watchdog.sh switch "$target" >/dev/null 2>&1
    rc=$?
    kill "$keeper" 2>/dev/null
    hb
    tail2=$(tail -n 2 /data/proxy/watchdog.log 2>/dev/null)
    if [ "$rc" = "0" ]; then
        send "Switch to $name: OK (data confirmed)
──────────────
$(sh /data/proxy/x28-status.sh 2>/dev/null | sed -n '1,5p')"
    else
        send "Switch to $name: NOT confirmed (rc=$rc).
──────────────
$tail2
Use /status to check the current state."
    fi
    return 0
}

# ---- beautiful output helpers (bot-wonderful 02) ----

# hr — section rule line.
hr() { echo "──────────────────────"; }

# fmt_status — the polished status card body.
fmt_status() {
    local out
    out=$(sh /data/proxy/x28-status.sh 2>/dev/null)
    [ -z "$out" ] && { echo "⚠️ status unavailable"; return; }
    # uppercase labels → emoji-prefixed aligned rows
    printf '%s\n' "$out" | awk '
    {
        lbl = $1; sub(/^[^ ]* */, "")
        key = $1
        val = substr($0, length(key) + 2)
        gsub(/_/, " ", key)
        icon = ""
        if (key == "operator")  icon = "📡"
        else if (key == "signal")    icon = "📶"
        else if (key == "data")      icon = "🌐"
        else if (key == "proxy")     icon = "🛰️"
        else if (key == "devices")   icon = "📱"
        else if (key == "uptime")    icon = "⏱"
        else if (key == "ram")       icon = "🧠"
        else if (key == "temp")      icon = "🌡"
        else if (key == "services")  icon = "⚙️"
        printf "%s %-9s %s\n", icon, toupper(substr(key,1,1)) substr(key,2), val
    }'
}

# fmt_devices — devices grouped by stable identity (hostname first), MAC shown
# only when it looks real (not locally-administered/randomized). Randomized
# MACs have the second hex nibble in {2,6,A,E} (locally administered bit set).
is_random_mac() {
    local m="${1:-}"
    case "$m" in
        ??[26aeAE]*:*) return 0 ;;   # x2/x6/xA/xE second nibble → randomized
        *) return 1 ;;
    esac
}

fmt_devices() {
    local leases="/tmp/dnsmasq.leases"
    [ -f "$leases" ] || { echo "no leases"; return; }
    awk '
    {
        mac = $2; ip = $3; host = $4
        if (host == "*" || host == "") host = "?"
        rnd = 0
        c = substr(mac, 2, 1)
        if (c ~ /[26aeAE]/) rnd = 1
        tag = rnd ? " 🎲" : ""
        printf "%-14s %-15s %s%s\n", host, ip, mac, tag
    }' "$leases" | sort
}

# help_text — full command list, grouped, pointing at the Panel buttons.
help_text() {
    cat <<'EOF'
🤖 X28 Bot — commands

📊 Status    /status   live overview
📶 Link      /link     modem signal detail
💾 Usage     /usage    per-device traffic today
💰 Balance   /balance  Samantel data left
💰 Budget    /budget   forecast + tiered alerts
🧾 Digest    /digest   weekly story (Fri 20:00)
🧾 Bill      /bill     weekly usage + cost
📱 Devices   /devices  who is on the network
🛰️ Proxy     /proxy    active node + health

🔄 Switch    /switch_mci · /switch_rightel
🎛 Panel     /panel    button grid (tap to navigate)

Everything also lives in the Panel buttons below ⤵️
EOF
}

# ---- bot mode: the long-poll command loop ----
bot() {
    oldpid=$(cat "$STATEDIR/bot.pid" 2>/dev/null)
    if [ -n "$oldpid" ] && [ "$oldpid" != "$$" ] && kill -0 "$oldpid" 2>/dev/null; then
        echo "bot already running (pid $oldpid)"; exit 1
    fi
    echo $$ > "$STATEDIR/bot.pid"
    hb
    log "bot: started pid=$$"

    # offset persists in /data: after a reboot Telegram would otherwise
    # redeliver the last command and re-run its side effects (a replayed
    # /switch_* once did exactly that).
    mkdir -p "$PSTATE"
    off=$(cat "$PSTATE/offset" 2>/dev/null || echo 0)
    while :; do
        hb
        resp=$(curl -s -m 60 -x "$PROXY" "$API/getUpdates?timeout=50&offset=$off" 2>/dev/null)
        ok=$(printf '%s' "$resp" | "$JQ" -r '.ok // "false"' 2>/dev/null)
        if [ "$ok" != "true" ]; then sleep 10; continue; fi
        n=$(printf '%s' "$resp" | "$JQ" '.result | length' 2>/dev/null)
        [ -z "$n" ] && { sleep 10; continue; }
        i=0
        while [ "$i" -lt "$n" ]; do
            uid=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].update_id" 2>/dev/null)
            cid=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].message.chat.id // \"\"" 2>/dev/null)
            text=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].message.text // \"\"" 2>/dev/null)
            mdate=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].message.date // \"\"" 2>/dev/null)
            # callback_query (Panel taps)
            cbid=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].callback_query.id // \"\"" 2>/dev/null)
            cbdata=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].callback_query.data // \"\"" 2>/dev/null)
            cbcid=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].callback_query.message.chat.id // \"\"" 2>/dev/null)
            cbmid=$(printf '%s' "$resp" | "$JQ" -r ".result[$i].callback_query.message.message_id // \"\"" 2>/dev/null)
            off=$((uid + 1)); echo "$off" > "$PSTATE/offset"
            hb
            if [ "$cbcid" = "$CHAT_ID" ] && [ -n "$cbdata" ]; then
                action=${cbdata#panel:}
                log "bot: panel tap=$action"
                case "$action" in
                    status)  body=$(fmt_status) ;;
                    link)    body="📶 Link detail
$(hr)
$(timeout 20 sh /data/proxy/linkstate.sh 2>/dev/null)" ;;
                    usage)   body="💾 Usage today
$(hr)
$(sh /data/proxy/usage/x28-usage.sh today 2>/dev/null)" ;;
                    balance) body="💰 Samantel balance
$(hr)
$(sh /root/balance.sh --report 2>/dev/null | head -12)" ;;
                    devices) body="📱 Devices on network
$(hr)
$(fmt_devices)" ;;
                    bill)    body="🧾 Weekly bill
$(hr)
$(sh /data/proxy/usage/x28-usage.sh week 2>/dev/null)" ;;
                    proxy)   body="🛰️ Proxy
$(hr)
active : $(curl -s -m 5 http://127.0.0.1:9090/proxies/auto 2>/dev/null | grep -o '"now":"[^"]*"' | cut -d'"' -f4)
health : $(sh /data/proxy/x28-health.sh 2>/dev/null | tail -1)" ;;
                    budget)  body="💰 Budget
$(hr)
$(sh /data/proxy/x28-budget.sh --card 2>/dev/null)" ;;
                    digest)  body="🧾 Digest
$(hr)
$(sh /data/proxy/x28-budget.sh --card 2>/dev/null | head -1)
$(sh /data/proxy/usage/x28-usage.sh week 2>/dev/null | tail -n +2)" ;;
                    help)    body="$(help_text)" ;;
                    panel|start) body="$(help_text)" ;;
                    *)       body="unknown tap" ;;
                esac
                answer_cbq "$cbid"
                [ -n "$cbmid" ] && edit_panel "$cbmid" "$(printf 'X28 Panel — %s\n──────────────\n%s' "$action" "$body")"
            elif [ "$cid" = "$CHAT_ID" ] && [ -n "$text" ]; then
                # staleness guard: anything older than 10 minutes is a replay
                # (reboot lost the offset once and an old /switch re-fired)
                if [ -n "$mdate" ] && [ $(( $(date +%s) - mdate )) -gt 600 ]; then
                    log "bot: skipped stale update uid=$uid (age $(( $(date +%s) - mdate ))s)"
                else
                cmd=$(printf '%s' "$text" | awk '{print $1}')
                log "bot: cmd=$cmd"
                case "$cmd" in
                    /start|/help)
                        send "$(help_text)"
                        send_panel ;;
                    /panel)
                        send_panel ;;
                    /status)
                        send "📊 X28 status
$(hr)
$(fmt_status)" ;;
                    /link)
                        send "📶 Link detail
$(hr)
$(timeout 20 sh /data/proxy/linkstate.sh 2>/dev/null)" ;;
                    /usage)
                        send "💾 Usage today
$(hr)
$(sh /data/proxy/usage/x28-usage.sh today 2>/dev/null)" ;;
                    /bill)
                        send "🧾 Weekly bill
$(hr)
$(sh /data/proxy/usage/x28-usage.sh week 2>/dev/null)" ;;
                    /balance)
                        send "💰 Samantel balance
$(hr)
$(sh /root/balance.sh --report 2>/dev/null | head -20)" ;;
                    /devices)
                        send "📱 Devices on network
$(hr)
$(fmt_devices)" ;;
                    /proxy)
                        send "🛰️ Proxy
$(hr)
active : $(curl -s -m 5 http://127.0.0.1:9090/proxies/auto 2>/dev/null | grep -o '"now":"[^"]*"' | cut -d'"' -f4)
health : $(sh /data/proxy/x28-health.sh 2>/dev/null | tail -1)" ;;
                    /budget)
                        send "💰 Budget
$(hr)
$(sh /data/proxy/x28-budget.sh --card 2>/dev/null)" ;;
                    /digest)
                        send "🧾 Digest
$(hr)
$(sh /data/proxy/x28-budget.sh --card 2>/dev/null | head -1)
$(sh /data/proxy/usage/x28-usage.sh week 2>/dev/null | tail -n +2)" ;;
                    /switch_mci)     do_switch "$MCI" "MCI" ;;
                    /switch_rightel) do_switch "$RIGHTEL" "Rightel" ;;
                    *) send "Unknown command — try /help" ;;
                esac
                fi
            elif [ -n "$cid" ] && [ "$cid" != "$CHAT_ID" ]; then
                log "bot: ignored update from chat $cid"
            fi
            i=$((i + 1))
        done
    done
}

# ---- supervise mode: start bot, cull wedges (stale heartbeat), restart ----
supervise() {
    while :; do
        sh "$SELF" bot >> "$LOGF" 2>&1 &
        bpid=$!
        log "supervisor: bot started pid=$bpid"
        culled=0
        while kill -0 "$bpid" 2>/dev/null; do
            sleep 20
            [ "$culled" = "1" ] && break
            hbv=$(cat "$HB" 2>/dev/null || echo 0)
            # empty/just-created hb file = write in progress: skip, never cull
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
        log "supervisor: bot gone, restarting in 5s"
        sleep 5
    done
}

case "${1:-supervise}" in
    bot)      bot ;;
    supervise) supervise ;;
    *)        echo "usage: x28-bot.sh [bot|supervise]"; exit 2 ;;
esac
