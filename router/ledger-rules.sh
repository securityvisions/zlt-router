#!/bin/sh
# ledger-rules.sh — Domain facade delegating to dedicated sub-domain modules:
[ -n "${_LEDGER_RULES_LOADED:-}" ] && return 0 2>/dev/null || true
_LEDGER_RULES_LOADED=1
#   1. outage-ledger.sh   (WAN Outage SLA, MTTR, duration formatting)
#   2. billing-ledger.sh  (Household bandwidth billing, budget tiers, owner lookup)
#
# Retains hn_bounce_decide for carrier/modem bearer bounce escalation.

# Source Outage Ledger
for _ol in \
    "$(dirname "$0")/outage-ledger.sh" \
    "$(dirname "$0")/x28/outage-ledger.sh" \
    "$(dirname "$0")/../outage-ledger.sh" \
    "$(dirname "$0")/../x28/outage-ledger.sh" \
    ./router/x28/outage-ledger.sh \
    /data/proxy/outage-ledger.sh \
    /root/outage-ledger.sh; do
    if [ -f "$_ol" ]; then . "$_ol"; break; fi
done

# Source Billing Ledger
for _bl in \
    "$(dirname "$0")/billing-ledger.sh" \
    "$(dirname "$0")/x28/billing-ledger.sh" \
    "$(dirname "$0")/../billing-ledger.sh" \
    "$(dirname "$0")/../x28/billing-ledger.sh" \
    ./router/x28/billing-ledger.sh \
    /data/proxy/billing-ledger.sh \
    /root/billing-ledger.sh; do
    if [ -f "$_bl" ]; then . "$_bl"; break; fi
done

# Carrier bearer bounce escalation (pure function)
hn_bounce_decide() {
    local r="${1:-0}" age="${2:-999999}" after="${3:-2}" cd="${4:-3600}"
    case "$r"   in *[!0-9]*) r=0      ;; esac
    case "$age" in *[!0-9]*) age=999999 ;; esac
    [ "$r" -ge "$after" ] && [ "$age" -ge "$cd" ] && { echo "yes"; return; }
    echo "no"
}
