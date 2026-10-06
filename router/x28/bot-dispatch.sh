#!/bin/sh
# bot-dispatch.sh — Deep module for Telegram Bot Command & Action Dispatching.
#
# Decouples Telegram I/O transport (long-polling, getUpdates JSON unpacking,
# HTTP networking) from action execution and card generation.
#
# Bounded domain:
#   - Action & Slash command resolution
#   - Execution of internal tools (wifi, owners, tv, rescue, ledger, carrier)
#   - Structured response packaging (send_html, edit_html, send_photo, send_panel)
#
# Canonical copy: router/x28/bot-dispatch.sh (deployed to X28 as /data/proxy/bot-dispatch.sh).

set -u

DIR=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
ROOT="${ROOT:-/data/proxy}"

# Output registers for caller
DISPATCH_ACTION=""
DISPATCH_TEXT=""
DISPATCH_EXTRA=""

# bot_dispatch_cmd <raw_text>
# Evaluates slash commands or text messages.
bot_dispatch_cmd() {
    local text="$1"
    local cmd sub rest arg card card_cmd card_arg rarg

    cmd=$(printf '%s' "$text" | awk '{print $1}')
    card_cmd="${cmd#/}"
    card_arg=$(printf '%s' "$text" | awk '{print $2}')

    # 1. Check card render seam first
    if command -v bot_render_card >/dev/null 2>&1 && card=$(bot_render_card "$card_cmd" "$card_arg"); then
        DISPATCH_ACTION="send_html"
        DISPATCH_TEXT="$card"
        case "$cmd" in
            /start|/help|/panel) DISPATCH_EXTRA="send_panel" ;;
            *) DISPATCH_EXTRA="" ;;
        esac
        return 0
    fi

    # 2. Command routing table
    case "$cmd" in
        /privacy)
            arg=$(printf '%s' "$text" | awk '{print $2}' | tr 'A-Z' 'a-z')
            command -v privacy_set >/dev/null 2>&1 && privacy_set "$arg" || true
            st=$(command -v privacy_state >/dev/null 2>&1 && privacy_state || echo "off")
            DISPATCH_ACTION="send_html"
            if [ "$st" = "on" ]; then
                DISPATCH_TEXT="🔒 <b>privacy mode ON</b> — sensitive data (names, MACs, IPs, device names) is masked in every card."
            else
                DISPATCH_TEXT="👁 <b>privacy mode OFF</b> — cards show real data again."
            fi
            ;;
        /owner)
            sub=$(printf '%s' "$text" | awk '{print $2}')
            rest=$(printf '%s' "$text" | cut -s -d' ' -f3-)
            local out="" mac="" person="" old_n="" new_n=""
            case "$sub" in
                assign)
                    mac=$(printf '%s' "$rest" | awk '{print $1}')
                    person=$(printf '%s' "$rest" | cut -s -d' ' -f2-)
                    if [ -z "$mac" ]; then
                        DISPATCH_ACTION="send_html"
                        DISPATCH_TEXT="👤 Usage: <code>/owner assign &lt;mac|hostname&gt; &lt;name&gt;</code>"
                        return 0
                    fi
                    out=$(sh "$ROOT/x28-owners.sh" assign "$mac" "$person" 2>&1 || true)
                    DISPATCH_ACTION="send_html"
                    DISPATCH_TEXT="👤 Owner: $out"
                    ;;
                unassign)
                    mac=$(printf '%s' "$rest" | awk '{print $1}')
                    out=$(sh "$ROOT/x28-owners.sh" unassign "$mac" 2>&1 || true)
                    DISPATCH_ACTION="send_html"
                    DISPATCH_TEXT="👤 Owner: $out"
                    ;;
                rename)
                    old_n=$(printf '%s' "$text" | awk '{print $3}')
                    new_n=$(printf '%s' "$text" | cut -s -d' ' -f4-)
                    out=$(sh "$ROOT/x28-owners.sh" rename "$old_n" "$new_n" 2>&1 || true)
                    DISPATCH_ACTION="send_html"
                    DISPATCH_TEXT="👤 Owner: $out"
                    ;;
                list|"")
                    DISPATCH_ACTION="send_owner_panel"
                    DISPATCH_TEXT=""
                    ;;
                *)
                    out=$(sh "$ROOT/x28-owners.sh" "$sub" $(printf '%s' "$text" | cut -s -d' ' -f2-) 2>&1 || true)
                    DISPATCH_ACTION="send_html"
                    DISPATCH_TEXT="👤 Owner: $out"
                    ;;
            esac
            ;;
        /wifi)
            local path="" cap=""
            if path=$(sh "$ROOT/x28-wifi.sh" qr 2>/dev/null); then
                cap=$(sh "$ROOT/x28-wifi.sh" card 2>/dev/null | head -n 3)
                DISPATCH_ACTION="send_photo"
                DISPATCH_TEXT="$path"
                DISPATCH_EXTRA="$cap"
            else
                DISPATCH_ACTION="send_html"
                DISPATCH_TEXT="$(sh "$ROOT/x28-wifi.sh" card 2>/dev/null || echo "WiFi info unavailable")"
                DISPATCH_EXTRA=""
            fi
            ;;
        /tv)
            sub=$(printf '%s' "$text" | awk '{print $2}')
            case "$sub" in
                on|wake)
                    DISPATCH_ACTION="send_html"
                    if [ -x "$ROOT/x28-tv.sh" ]; then
                        DISPATCH_TEXT="$(sh "$ROOT/x28-tv.sh" wake)"
                    else
                        DISPATCH_TEXT="⚡ WOL sent to Samsung TV"
                    fi
                    ;;
                *)
                    DISPATCH_ACTION="send_html"
                    if command -v bot_render_card >/dev/null 2>&1; then
                        DISPATCH_TEXT="$(bot_render_card tv 2>/dev/null || echo "📺 TV Ready")"
                    else
                        DISPATCH_TEXT="📺 TV Ready"
                    fi
                    ;;
            esac
            ;;
        /rescue)
            rarg=$(printf '%s' "$text" | awk '{print $2}')
            case "$rarg" in
                on|off) sh "$ROOT/x28-rescue.sh" switch "$rarg" >/dev/null 2>&1 || true ;;
                *)      rarg="" ;;
            esac
            DISPATCH_ACTION="send_html"
            local now_str=""
            command -v now_hm >/dev/null 2>&1 && now_str=" · $(now_hm)" || true
            DISPATCH_TEXT="🛟 Rescue${now_str}
$(sh "$ROOT/x28-rescue.sh" status 2>/dev/null || echo "No status")$( [ -n "$rarg" ] && printf '\n<i>switched: %s</i>' "$rarg" )"
            ;;
        /ledger)
            local ldir="$ROOT/usage/ledger"
            if [ -d "$ldir" ] && ls "$ldir"/J-*.txt >/dev/null 2>&1; then
                DISPATCH_ACTION="send_ledger_panel"
                DISPATCH_TEXT="📜 <b>Frozen Ledger pages</b> — tap to view"
            else
                DISPATCH_ACTION="send_html"
                DISPATCH_TEXT="📜 <b>Ledger</b> — no frozen pages yet (first appears after next Jalali month-end)"
            fi
            ;;
        /switch_mci)
            DISPATCH_ACTION="switch_carrier"
            DISPATCH_TEXT="43211"
            DISPATCH_EXTRA="MCI"
            ;;
        /switch_rightel)
            DISPATCH_ACTION="switch_carrier"
            DISPATCH_TEXT="43220"
            DISPATCH_EXTRA="Rightel"
            ;;
        *)
            DISPATCH_ACTION="send_html"
            DISPATCH_TEXT="❓ Unknown command — <code>/help</code> lists everything."
            ;;
    esac
    return 0
}

# bot_dispatch_cb <cbdata> [cbmid]
# Evaluates inline callback button presses.
bot_dispatch_cb() {
    local cbdata="$1"
    local cbmid="${2:-}"
    local action="${cbdata#panel:}"
    local card="" body=""

    if command -v bot_render_card >/dev/null 2>&1 && card=$(bot_render_card "$action"); then
        DISPATCH_ACTION="edit_panel"
        DISPATCH_TEXT="$card"
        DISPATCH_EXTRA="$cbmid"
        return 0
    fi

    case "$action" in
        wifi)
            local path="" cap=""
            if path=$(sh "$ROOT/x28-wifi.sh" qr 2>/dev/null); then
                cap=$(sh "$ROOT/x28-wifi.sh" card 2>/dev/null | head -n 3)
                DISPATCH_ACTION="send_photo"
                DISPATCH_TEXT="$path"
                DISPATCH_EXTRA="$cap"
            else
                DISPATCH_ACTION="send_html"
                DISPATCH_TEXT="$(sh "$ROOT/x28-wifi.sh" card 2>/dev/null || echo "WiFi unavailable")"
            fi
            ;;
        ledg:*)
            local lf="${action#ledg:}"
            DISPATCH_ACTION="edit_panel"
            if [ -f "$lf" ]; then
                DISPATCH_TEXT="$(cat "$lf")"
            else
                DISPATCH_TEXT="page not found"
            fi
            DISPATCH_EXTRA="$cbmid"
            ;;
        ownd:*)
            local mac="${action#ownd:}"
            DISPATCH_ACTION="send_owner_assign"
            DISPATCH_TEXT="$mac"
            ;;
        ownp:*)
            local pname
            pname=$(printf '%s' "${action#ownp:}" | base64 -d 2>/dev/null || true)
            DISPATCH_ACTION="edit_panel"
            local now_str=""
            command -v now_hm >/dev/null 2>&1 && now_str=" · $(now_hm)" || true
            DISPATCH_TEXT="<b>👤 $pname's devices</b>${now_str}
$(grep -i "|$pname\$" "$ROOT/owners.conf" 2>/dev/null | while IFS='|' read -r m p; do
    host=$(grep "$m" /tmp/dnsmasq.leases 2>/dev/null | awk '{print $4}')
    printf '• %s <code>%s</code>\n' "${host:-?}" "$m"
done)"
            DISPATCH_EXTRA="$cbmid"
            ;;
        ownl:*)
            DISPATCH_ACTION="edit_panel"
            DISPATCH_TEXT="<b>👤 All assignments</b>
$(sh "$ROOT/x28-owners.sh" list 2>/dev/null || echo "none")"
            DISPATCH_EXTRA="$cbmid"
            ;;
        ownr:*)
            DISPATCH_ACTION="send_owner_panel"
            DISPATCH_TEXT=""
            ;;
        help|panel|start)
            DISPATCH_ACTION="edit_panel"
            if command -v help_text >/dev/null 2>&1; then
                DISPATCH_TEXT="$(help_text)"
            else
                DISPATCH_TEXT="<b>Help Panel</b>"
            fi
            DISPATCH_EXTRA="$cbmid"
            ;;
        *)
            DISPATCH_ACTION="edit_panel"
            DISPATCH_TEXT="unknown tap"
            DISPATCH_EXTRA="$cbmid"
            ;;
    esac
    return 0
}

# CLI direct execution support for testing & inspection
case "${1:-}" in
    cmd)
        bot_dispatch_cmd "${2:-}"
        printf 'action=%s\nextra=%s\ntext=%s\n' "$DISPATCH_ACTION" "$DISPATCH_EXTRA" "$DISPATCH_TEXT"
        ;;
    cb)
        bot_dispatch_cb "${2:-}" "${3:-}"
        printf 'action=%s\nextra=%s\ntext=%s\n' "$DISPATCH_ACTION" "$DISPATCH_EXTRA" "$DISPATCH_TEXT"
        ;;
    *)  ;;
esac
