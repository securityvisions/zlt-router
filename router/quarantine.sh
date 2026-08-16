#!/bin/sh
# quarantine.sh — device quarantine gate (opt-in).
#
# Canonical copy lives in this repo (router/quarantine.sh); deployed to the
# AX3000T as /root/quarantine.sh. When enabled (/etc/quarantine-enabled), new
# devices not in the approved list are blocked from the internet (fw4 forward
# drop) until a MAC is approved. Approval lives in /etc/quarantine-allow; the
# bot's /approve command writes it. Reversible: disable removes the flag and
# the drop rules.

# Shared home-network module (event recorder). Guarded: `.` on a missing file is
# a fatal special-builtin error, and quarantine must survive without hnlib.
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] && . "$HN_LIB"

ALLOW="${QUARANTINE_ALLOW:-/etc/quarantine-allow}"
EXEMPT="${QUARANTINE_EXEMPT:-/etc/quarantine-exempt}"
FLAG="${QUARANTINE_FLAG:-/etc/quarantine-enabled}"

# qw_blocked <leases> <allow> <exempt> — pure; prints the MACs that should be
# blocked: leased MACs that are neither approved nor exempt.
qw_blocked() {
    local leases="$1" allow="$2" exempt="$3" mac
    [ -f "$leases" ] || return 0
    awk '{print $2}' "$leases" | sort -u | while read -r mac; do
        [ -z "$mac" ] && continue
        grep -qx "$mac" "$allow" 2>/dev/null && continue
        grep -qx "$mac" "$exempt" 2>/dev/null && continue
        echo "$mac"
    done
}

# qw_enforced <leases> — prints only the blocked MACs that already have a drop
# rule (so enforce() is idempotent and status is honest).
qw_enforced() {
    local leases="$1" mac rule
    [ -f "$leases" ] || return 0
    awk '{print $2}' "$leases" | sort -u | while read -r mac; do
        [ -z "$mac" ] && continue
        if nft -a list chain inet fw4 forward 2>/dev/null | grep -q "ether saddr $mac drop"; then
            echo "$mac"
        fi
    done
}

qw_block() {  # qw_block <mac> — add the fw4 drop rule (idempotent).
    nft -a add rule inet fw4 forward ether saddr "$1" drop 2>/dev/null
}

qw_unblock() {  # qw_unblock <mac> — remove every drop rule for this MAC.
    nft -a list chain inet fw4 forward 2>/dev/null |
        awk -v m="$1" '$0 ~ ("ether saddr " m " drop") {
            for (i = 1; i <= NF; i++) if ($i == "handle") print $(i + 1)
        }' |
        while read -r h; do
            [ -n "$h" ] && nft delete rule inet fw4 forward handle "$h" 2>/dev/null
        done
}

enforce() {  # enforce <leases> — block every unapproved device; unblock the rest.
    local blocked mac leases="$1" already
    blocked=$(qw_blocked "$leases" "$ALLOW" "$EXEMPT")
    already=$(qw_enforced "$leases")
    printf '%s\n' "$blocked" | while read -r mac; do
        [ -z "$mac" ] && continue
        qw_block "$mac"
        # record only the newly-blocked (qw_enforced listed it before this pass)
        if ! printf '%s\n' "$already" | grep -qx "$mac"; then
            hn_event_record device_blocked "quarantine: device blocked" "$mac" >/dev/null 2>&1 || true
        fi
    done
    # unblock approved/exempt devices that may still carry a stale rule
    awk '{print $2}' "$leases" 2>/dev/null | sort -u | while read -r mac; do
        [ -z "$mac" ] && continue
        if grep -qx "$mac" "$ALLOW" 2>/dev/null || grep -qx "$mac" "$EXEMPT" 2>/dev/null; then
            qw_unblock "$mac"
        fi
    done
}

# qw_approve <mac> — approve a MAC (persists; caller unblocks it).
qw_approve() {
    mkdir -p "$(dirname "$ALLOW")"
    grep -qx "$1" "$ALLOW" 2>/dev/null || echo "$1" >> "$ALLOW"
    qw_unblock "$1"
    hn_event_record device_approved "quarantine: device approved" "$1" >/dev/null 2>&1 || true
    echo "approved $1"
}

# qw_revoke <mac> — remove approval (blocks at the next enforce pass).
qw_revoke() {
    [ -f "$ALLOW" ] || return 0
    grep -vx "$1" "$ALLOW" > "$ALLOW.tmp" 2>/dev/null && mv "$ALLOW.tmp" "$ALLOW" 2>/dev/null
    echo "revoked $1"
}

main() {
    [ -e "$FLAG" ] || { echo "quarantine: disabled"; exit 0; }
    enforce /tmp/dhcp.leases
    echo "quarantine: enabled; $(qw_blocked /tmp/dhcp.leases "$ALLOW" "$EXEMPT" | grep -c . || echo 0) device(s) blocked"
}

case "${1:-}" in
    --blocked) qw_blocked "${2:-/tmp/dhcp.leases}" "$ALLOW" "$EXEMPT" ;;
    --enforced) qw_enforced "${2:-/tmp/dhcp.leases}" ;;
    --approve) qw_approve "$2" ;;
    --revoke) qw_revoke "$2" ;;
    --status) [ -e "$FLAG" ] && echo enabled || echo disabled ;;
    *) main ;;
esac
