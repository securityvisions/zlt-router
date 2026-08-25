#!/bin/sh
# udp-diag.sh — UDP-path diagnostic for the Steam voice question.
#
# Steam voice is WebRTC over UDP; the X28's transparent proxy only tunnels
# TCP, so voice UDP goes direct and (likely) gets filtered. This script
# answers the two questions that decide whether to build a UDP TPROXY path:
#   1. is direct UDP from the LAN actually filtered?
#   2. which proxy node has the lowest latency for a voice fallback path?
#
# Modes:
#   udp-diag.sh nodes    — rank auto-group nodes by measured delay (parallel)
#   udp-diag.sh egress   — UDP egress check: resolve a foreign name via UDP 53
#   udp-diag.sh steam    — reachability to a Valve voice-range IP + the exact
#                          PC-side UDP test to run on the machine playing Steam
#   udp-diag.sh verdict  — recommendation from the gathered checks
#   udp-diag.sh all      — run everything and print the verdict
#
# Env seams for tests: MIHOMO_CTRL, JQ_BIN, NSLOOKUP_CMD, PING_CMD, CURL_CMD,
# DIAG_RESOLVER, DIAG_DOMAIN, DIAG_STEAM_IP, DIAG_EGRESS, DIAG_STEAM_REACH,
# DIAG_BEST_MS, DIAG_BEST_NODE.
#
# Canonical copy: router/x28/udp-diag.sh — deploys to /data/proxy/udp-diag.sh.

JQ="${JQ_BIN:-/data/proxy/jq}"
CTRL="${MIHOMO_CTRL:-http://127.0.0.1:9090}"
NSLOOKUP="${NSLOOKUP_CMD:-nslookup}"
PING="${PING_CMD:-ping}"
CURL="${CURL_CMD:-curl}"
RESOLVER="${DIAG_RESOLVER:-8.8.8.8}"
DOMAIN="${DIAG_DOMAIN:-www.google.com}"
STEAM_IP="${DIAG_STEAM_IP:-162.254.197.1}"

diag_nodes() {
    auto=$(curl -s -m 6 "$CTRL/proxies/auto" 2>/dev/null)
    members=$(printf '%s' "$auto" | "$JQ" -r '.all // [] | .[]' 2>/dev/null)
    tmpd=$(mktemp -d 2>/dev/null)
    url="https%3A%2F%2Fwww.gstatic.com%2Fgenerate_204"
    for m in $members; do
        (
            r=$(curl -s -m 12 "$CTRL/proxies/$m/delay?url=$url&timeout=8000" 2>/dev/null)
            d=$(printf '%s' "$r" | "$JQ" -r '.delay // "error"' 2>/dev/null)
            printf '%s' "$d" > "$tmpd/$m"
        ) &
    done
    wait
    # rank: numeric ms ascending, error nodes last
    for f in "$tmpd"/*; do
        [ -f "$f" ] || continue
        n=$(basename "$f"); v=$(cat "$f")
        case "$v" in
            *error*) printf '999999\t%s error\n' "$n" ;;
            *)       printf '%s\t%s\n' "$v" "$n" ;;
        esac
    done | sort -n -k1,1 | awk -F'\t' '{ if ($1 == "999999") printf "%s error\n", $2; else printf "%s %s\n", $2, $1 }'
    rm -rf "$tmpd"
}

diag_egress() {
    if [ -n "$DIAG_EGRESS" ]; then
        echo "$DIAG_EGRESS"; return 0
    fi
    out=$($NSLOOKUP "$DOMAIN" "$RESOLVER" 2>&1)
    case "$out" in
        *[0-9]*.[0-9]*.[0-9]*.[0-9]*) echo pass ;;
        *) echo fail ;;
    esac
}

diag_steam() {
    # ICMP + TCP reachability to the Valve voice range head (busybox-safe)
    reach="no"
    $PING -c1 -W2 "$STEAM_IP" >/dev/null 2>&1 && reach="yes"
    $CURL -s -m3 -o /dev/null "http://$STEAM_IP:27000" 2>/dev/null && reach="yes"
    [ -n "$DIAG_STEAM_REACH" ] && reach="$DIAG_STEAM_REACH"
    echo "steam_voice_ip=$STEAM_IP reach=$reach"
    echo
    echo "PC-side UDP test (run on the machine playing Steam):"
    echo "  powershell Test-NetConnection -ComputerName $STEAM_IP -Port 27000 -InformationLevel Detailed"
    echo "A 'TcpTestSucceeded : False' with the router's normal network is normal for UDP-only voice;"
    echo "the real signal is the Steam voice channel itself: join with proxy-mode TCP only,"
    echo "then compare after a UDP path exists."
}

diag_verdict() {
    egress="${DIAG_EGRESS:-$(diag_egress)}"
    reach="${DIAG_STEAM_REACH:-no}"
    best_ms="${DIAG_BEST_MS:-0}"
    best_node="${DIAG_BEST_NODE:-none}"
    echo "── verdict ───────────────────────────────"
    echo "udp_egress=$egress  steam_reach=$reach  best_node=$best_node ($best_ms ms)"
    echo
    if [ "$egress" = "fail" ]; then
        echo "UDP egress from the LAN is broken entirely — even DNS-over-UDP fails."
        echo "No TPROXY will help until the ISP/radio allows UDP out at all. Fix upstream first."
    elif [ "$reach" = "no" ]; then
        echo "Steam voice-range hosts are unreachable (ICMP+TCP) from here."
        echo "If UDP egress is fine but Steam hosts are blocked, a proxy UDP path (TPROXY) is likely needed."
    else
        echo "Steam hosts reachable and UDP egress works — yet voice fails: this is classic"
        echo "Steam-specific UDP filtering. The fix is the proxy path (build the TPROXY);"
        echo "expect ~${best_ms} ms added RTT via node ${best_node} — voice will lag ($([ "$best_ms" -gt 300 ] && echo yes || echo no))"
        if [ "$best_ms" -gt 300 ] 2>/dev/null; then
            echo "Voice will lag through the current VPS path; pick the UDP-native node (03) for the best chance."
        fi
    fi
}

case "${1:-all}" in
    nodes)   diag_nodes ;;
    egress)  diag_egress ;;
    steam)   diag_steam ;;
    verdict) diag_verdict ;;
    all)
        echo "── node latency ranking ───────────────"
        nodes=$(diag_nodes)
        printf '%s\n' "$nodes"
        echo
        echo "── UDP egress check ───────────────────"
        e=$(diag_egress); echo "udp_egress=$e"
        echo
        echo "── Steam voice reachability ───────────"
        diag_steam
        echo
        best=$(printf '%s\n' "$nodes" | grep -v error | head -1 | awk '{print $1, $2}')
        bnode=$(printf '%s' "$best" | awk '{print $1}'); bms=$(printf '%s' "$best" | awk '{print $2}')
        DIAG_EGRESS="$e" DIAG_STEAM_REACH="$([ "$reach" = "yes" ] && echo yes || echo no)" \
        DIAG_BEST_NODE="$bnode" DIAG_BEST_MS="$bms" diag_verdict
        ;;
    *) echo "usage: udp-diag.sh [nodes|egress|steam|verdict|all]" >&2; exit 2 ;;
esac