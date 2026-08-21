#!/bin/sh
# x28-bot.sh — Telegram remote control for the X28 (@xirouterbot).
#
# Commands (only from the allowlisted chat in /etc/tg.conf):
#   /status /link /switch_mci /switch_rightel /help (/start = /help)
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
LOGF=$STATEDIR/bot.log
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
            off=$((uid + 1)); echo "$off" > "$PSTATE/offset"
            hb
            if [ "$cid" = "$CHAT_ID" ] && [ -n "$text" ]; then
                # staleness guard: anything older than 10 minutes is a replay
                # (reboot lost the offset once and an old /switch re-fired)
                if [ -n "$mdate" ] && [ $(( $(date +%s) - mdate )) -gt 600 ]; then
                    log "bot: skipped stale update uid=$uid (age $(( $(date +%s) - mdate ))s)"
                else
                cmd=$(printf '%s' "$text" | awk '{print $1}')
                log "bot: cmd=$cmd"
                case "$cmd" in
                    /start|/help)
                        send "X28 bot — commands:
/status — full status card
/link — modem/link details
/switch_mci — switch to MCI ($MCI)
/switch_rightel — switch to Rightel ($RIGHTEL)
/help — this help" ;;
                    /status)
                        send "X28 status
──────────────
$(sh /data/proxy/x28-status.sh 2>/dev/null)" ;;
                    /link)
                        send "X28 link detail
──────────────
$(timeout 20 sh /data/proxy/linkstate.sh 2>/dev/null)" ;;
                    /usage)
                        send "X28 usage
──────────────
$(sh /data/proxy/usage/x28-usage.sh today 2>/dev/null)" ;;
                    /bill)
                        send "X28 weekly usage + bill
──────────────
$(sh /data/proxy/usage/x28-usage.sh week 2>/dev/null)" ;;
                    /balance)
                        send "X28 balance
──────────────
$(sh /root/balance.sh --report 2>/dev/null | head -20)" ;;
                    /switch_mci)     do_switch "$MCI" "MCI" ;;
                    /switch_rightel) do_switch "$RIGHTEL" "Rightel" ;;
                    *) send "Unknown command. Try /help" ;;
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
