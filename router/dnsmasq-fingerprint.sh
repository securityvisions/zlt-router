#!/bin/sh
# /etc/dnsmasq-fingerprint.sh — Event-driven DHCP Fingerprinter Hook for OpenWrt dnsmasq
# Invoked by dnsmasq whenever a DHCP lease is created, renewed, or deleted.

ACTION="${1:-}"
MAC="${2:-}"
IP="${3:-}"
HOST="${4:-}"

[ "$ACTION" = "add" ] || [ "$ACTION" = "old" ] || exit 0
[ -z "$MAC" ] && exit 0

NAMES_CACHE="/etc/usage-log/names"
INVENTORY="/etc/usage-log/device-inventory.tsv"
IDENTIFIER="/root/device-identifier.sh"
[ -x "$IDENTIFIER" ] || IDENTIFIER="/usr/sbin/device-identifier.sh"

PRL="${DNSMASQ_REQUESTED_OPTIONS:-}"
VCI="${DNSMASQ_VENDOR_CLASS:-}"
[ -z "$HOST" ] && HOST="${DNSMASQ_SUPPLIED_HOSTNAME:-}"

mkdir -p /etc/usage-log 2>/dev/null || true

# Auto-link rotating MAC to canonical device if recognizable
UNIFIER="/root/device-unifier.sh"
[ -x "$UNIFIER" ] || UNIFIER="/usr/sbin/device-unifier.sh"
if [ -x "$UNIFIER" ]; then
    "$UNIFIER" auto-link "$MAC" "$HOST" "$PRL" "$VCI" 2>/dev/null || true
fi

# Call device-identifier if present, else fallback
LABEL=""
if [ -x "$IDENTIFIER" ]; then
    LABEL=$("$IDENTIFIER" identify "$MAC" "$HOST" "$PRL" "$VCI" 2>/dev/null || true)
fi

[ -z "$LABEL" ] && [ -n "$HOST" ] && LABEL="$HOST"
[ -z "$LABEL" ] && LABEL="Device-$(printf '%s' "$MAC" | cut -d: -f4-6)"

# Update /etc/usage-log/names
grep -v "^$MAC " "$NAMES_CACHE" 2>/dev/null > "$NAMES_CACHE.tmp" || true
echo "$MAC $LABEL" >> "$NAMES_CACHE.tmp"
mv -f "$NAMES_CACHE.tmp" "$NAMES_CACHE" 2>/dev/null || true

# Update inventory TSV: MAC IP LABEL PRL VCI TIMESTAMP
TS=$(date '+%Y-%m-%d %H:%M:%S')
grep -v "^$MAC	" "$INVENTORY" 2>/dev/null > "$INVENTORY.tmp" || true
printf '%s\t%s\t%s\t%s\t%s\t%s\n' "$MAC" "$IP" "$LABEL" "$PRL" "$VCI" "$TS" >> "$INVENTORY.tmp"
mv -f "$INVENTORY.tmp" "$INVENTORY" 2>/dev/null || true

exit 0
