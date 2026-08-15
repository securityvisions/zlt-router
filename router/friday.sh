#!/bin/sh
# Friday discount reminder - sends a Telegram alert on Fridays at 09:00
# Usage:
#   friday.sh            - cron entry (0 9 * * 5); honors toggle + day check
#   friday.sh --test     - send immediately regardless of day/toggle
. /etc/billing.conf 2>/dev/null

if [ "$1" != "--test" ]; then
    # honor the toggle (FRIDAY_REMINDER=on|off in /etc/billing.conf)
    case "${FRIDAY_REMINDER:-on}" in
        on|ON|1|yes) : ;;
        *) exit 0 ;;
    esac
    # must be Friday (cron already guards this; belt-and-braces)
    [ "$(date +%u)" = "5" ] || exit 0
fi

msg="🟢 It's Friday — 40% off Samantel packages today! Send /balance to check your data."

# best-effort: append current package balance (non-blocking, timed out)
total=$(timeout 20 /root/balance.sh --report 2>/dev/null | head -1 | sed 's/^📦 Samantel — //')
[ -n "$total" ] && msg="${msg}

📦 ${total}"

/root/tg.sh "$msg"
