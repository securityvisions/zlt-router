#!/bin/sh
# probe-service.sh — one probing budget for Link / PassWall / VPS origin.
# Unifies the 7 probe isolates (generate_204 vs instagram vs 1.1.1.1 vs ipify)
# into ProbeService.check() with ProbeProfile per context. Adding a via_x28
# node no longer means editing 3 probe lists.
# Canonical copy: router/x28/probe-service.sh — deploys to /data/proxy/probe-service.sh
# Test seam: PROBE_URL, PROBE_TIMEOUT, PROBE_SOCKS env overrides.

PROBE_URL="${PROBE_URL:-https://www.gstatic.com/generate_204}"
PROBE_TIMEOUT="${PROBE_TIMEOUT:-5}"
PROBE_SOCKS="${PROBE_SOCKS:-127.0.0.1:1070}"

# probe_check [profile] — profile: link|passwall|vps (affects URL/timeout via env)
# Returns 0 when proxied path alive (HTTP 204/200), 1 otherwise.
probe_check() {
    local profile="${1:-link}" url timeout socks
    case "$profile" in
        link) url="${LINK_PROBE_URL:-$PROBE_URL}"; timeout="${LINK_PROBE_TIMEOUT:-$PROBE_TIMEOUT}"; socks="${LINK_PROBE_SOCKS:-$PROBE_SOCKS}" ;;
        passwall) url="${PASSWALL_PROBE_URL:-$PROBE_URL}"; timeout="${PASSWALL_PROBE_TIMEOUT:-$PROBE_TIMEOUT}"; socks="${PASSWALL_PROBE_SOCKS:-$PROBE_SOCKS}" ;;
        vps) url="${VPS_PROBE_URL:-http://85.121.124.158:2095/}"; timeout="${VPS_PROBE_TIMEOUT:-10}"; socks="" ;;
        *) url="$PROBE_URL"; timeout="$PROBE_TIMEOUT"; socks="$PROBE_SOCKS" ;;
    esac
    local code
    if [ -n "$socks" ]; then
        code=$(curl -sS -m "$timeout" --socks5 "$socks" -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)
    else
        code=$(curl -sS -m "$timeout" -o /dev/null -w '%{http_code}' "$url" 2>/dev/null)
    fi
    case "$code" in 200|204) return 0 ;; *) return 1 ;; esac
}

# probe_profile — prints current profile env for debugging
probe_profile() {
    printf 'link: url=%s timeout=%s socks=%s\n' "${LINK_PROBE_URL:-$PROBE_URL}" "${LINK_PROBE_TIMEOUT:-$PROBE_TIMEOUT}" "${LINK_PROBE_SOCKS:-$PROBE_SOCKS}"
    printf 'passwall: url=%s timeout=%s socks=%s\n' "${PASSWALL_PROBE_URL:-$PROBE_URL}" "${PASSWALL_PROBE_TIMEOUT:-$PROBE_TIMEOUT}" "${PASSWALL_PROBE_SOCKS:-$PROBE_SOCKS}"
}
