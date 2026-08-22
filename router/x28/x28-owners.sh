#!/bin/sh
# x28-owners.sh — device → person assignment (owners.conf).
# Usage: x28-owners.sh list | assign <mac> <person> | unassign <mac> | get <mac>
# Env: OWNERS_FILE
set -eu

OWNERS_FILE="${OWNERS_FILE:-/data/proxy/owners.conf}"
HN_LIB="${HN_LIB:-/root/hnlib.sh}"
[ -f "$HN_LIB" ] || HN_LIB="/data/proxy/hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$(dirname "$0")/../hnlib.sh"
[ -f "$HN_LIB" ] && . "$HN_LIB" 2>/dev/null || true

cmd="${1:-list}"
case "$cmd" in
    list)
        if [ ! -f "$OWNERS_FILE" ] || [ ! -s "$OWNERS_FILE" ]; then
            echo "No owners yet — assign with: /owner <mac> <person>"
            echo "Find MACs via /devices"
            exit 0
        fi
        echo "👤 Owners"
        echo "──────────────"
        cat "$OWNERS_FILE" 2>/dev/null | while IFS='|' read -r mac person; do
            [ -z "$mac" ] && continue
            printf '%-17s → %s\n' "$mac" "$person"
        done
        ;;
    assign)
        mac="${2:-}"; person="${3:-}"
        # join ALL remaining words as the person name ("/owner assign <mac> Ali Reza")
        if [ -n "$mac" ] && [ $# -ge 3 ]; then
            shift 2
            person="$*"
        fi
        if [ -z "$mac" ] || [ -z "$person" ]; then
            echo "Usage: /owner assign <mac> <person>"
            exit 1
        fi
        # normalize mac lower
        mac_lc=$(printf '%s' "$mac" | tr 'A-Z' 'a-z')
        # validate mac format (basic)
        case "$mac_lc" in
            ??:??:??:??:??:??) ;;
            *) echo "Invalid MAC: $mac"; exit 1 ;;
        esac
        mkdir -p "$(dirname "$OWNERS_FILE")" 2>/dev/null
        touch "$OWNERS_FILE" 2>/dev/null
        chmod 600 "$OWNERS_FILE" 2>/dev/null || true
        # remove existing entry case-insensitive
        tmp=$(mktemp)
        grep -vi "^$(printf '%s' "$mac_lc" | sed 's/[][\.*^$]/\\&/g')|" "$OWNERS_FILE" 2>/dev/null > "$tmp" || true
        printf '%s|%s\n' "$mac_lc" "$person" >> "$tmp"
        sort -u "$tmp" > "$OWNERS_FILE" 2>/dev/null
        rm -f "$tmp"
        echo "✅ $mac → $person"
        ;;
    unassign)
        mac="${2:-}"
        [ -n "$mac" ] || { echo "Usage: /owner unassign <mac>"; exit 1; }
        mac_lc=$(printf '%s' "$mac" | tr 'A-Z' 'a-z')
        [ -f "$OWNERS_FILE" ] || { echo "No owners file"; exit 0; }
        tmp=$(mktemp)
        grep -vi "^$(printf '%s' "$mac_lc" | sed 's/[][\.*^$]/\\&/g')|" "$OWNERS_FILE" 2>/dev/null > "$tmp" || true
        cat "$tmp" > "$OWNERS_FILE" 2>/dev/null
        rm -f "$tmp"
        echo "🗑️ $mac unassigned"
        ;;
    get)
        mac="${2:-}"
        [ -n "$mac" ] || { echo ""; exit 1; }
        if command -v hn_owner_of >/dev/null 2>&1; then
            hn_owner_of "$mac" "$OWNERS_FILE"
        else
            want=$(printf '%s' "$mac" | tr 'A-Z' 'a-z')
            grep -i "^$(printf '%s' "$want" | sed 's/[][\.*^$]/\\&/g')|" "$OWNERS_FILE" 2>/dev/null | head -1 | cut -d'|' -f2- | sed 's/^[[:space:]]*//;s/[[:space:]]*$//'
        fi
        ;;
    *)
        # try to handle as: /owner <mac> <person>  (shorthand assign)
        if [ -n "$cmd" ] && printf '%s' "$cmd" | grep -q ":"; then
            # first arg looks like mac
            mac="$cmd"; shift
            person="$*"
            if [ -n "$person" ]; then
                exec "$0" assign "$mac" "$person"
            else
                echo "Usage: /owner <mac> <person>  or  /owner list"
                exit 1
            fi
        else
            echo "Usage: /owner list | /owner assign <mac> <person> | /owner unassign <mac>"
            exit 1
        fi
        ;;
esac
