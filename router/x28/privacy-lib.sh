#!/bin/sh
# privacy-lib.sh — privacy scrub module for the Telegram surface.
#
# One toggleable state (/data/proxy/privacy.conf, PRIVACY=1) and one scrub
# filter used at the send funnels of the bot and the alerts path, so a demo
# recording never shows real MACs, IPs, owner names, or device hostnames.
# When privacy is off, text passes through untouched.
#
# Exports:
#   privacy_on            — true when privacy mode is active
#   privacy_toggle        — flip the state file, 0600
#   privacy_state         — "on" | "off"
#   privacy_scrub <text>  — mask sensitive values when on; else echo unchanged
#
# Env seams for tests: PRIVACY_CONF, HN_OWNERS_FILE, HN_LEASES.

PRIVACY_CONF="${PRIVACY_CONF:-/data/proxy/privacy.conf}"

privacy_on() {
    [ -f "$PRIVACY_CONF" ] || return 1
    grep -q '^PRIVACY=1' "$PRIVACY_CONF" 2>/dev/null
}

privacy_toggle() {
    if privacy_on; then
        printf 'PRIVACY=0\n' > "$PRIVACY_CONF" 2>/dev/null
    else
        printf 'PRIVACY=1\n' > "$PRIVACY_CONF" 2>/dev/null
    fi
    chmod 600 "$PRIVACY_CONF" 2>/dev/null
}

privacy_state() { if privacy_on; then echo on; else echo off; fi; }

# esc_re <text> — escape a literal string for use as a sed pattern
esc_re() { printf '%s' "$1" | sed 's/[][\.*^$/]/\\&/g'; }

# privacy_scrub <text> — mask MACs, IPs, owner names, device hostnames.
privacy_scrub() {
    local text="$1"
    if ! privacy_on; then
        printf '%s' "$text"
        return 0
    fi
    # MAC addresses
    text=$(printf '%s' "$text" | sed -E 's/[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}/••••/g')
    # IP addresses
    text=$(printf '%s' "$text" | sed -E 's/[0-9]{1,3}(\.[0-9]{1,3}){3}/•••/g')
    # owner names (from the owners file)
    local owners="${HN_OWNERS_FILE:-/data/proxy/owners.conf}" _m _p
    if [ -f "$owners" ]; then
        while IFS='|' read -r _m _p; do
            [ -n "$_p" ] || continue
            text=$(printf '%s' "$text" | sed "s/$(esc_re "$_p")/User/g")
        done < "$owners"
    fi
    # device hostnames (from live leases: expiry mac ip hostname clientid)
    local leases="${HN_LEASES:-/tmp/dnsmasq.leases}" _e _mac _ip _h _rest
    if [ -f "$leases" ]; then
        while read -r _e _mac _ip _h _rest; do
            [ -n "$_h" ] && [ "$_h" != "*" ] || continue
            text=$(printf '%s' "$text" | sed "s/$(esc_re "$_h")/Device/g")
        done < "$leases"
    fi
    printf '%s' "$text"
}

# ---------- CLI (skipped when sourced) ----------
if [ "${0##*/}" = "privacy-lib.sh" ]; then
case "${1:-}" in
    state) privacy_state ;;
    toggle) privacy_toggle; privacy_state ;;
    scrub) shift; privacy_scrub "${1:-}" ;;
    *) echo "usage: privacy-lib.sh [state|toggle|scrub <text>]" >&2; exit 2 ;;
esac
fi