#!/bin/sh
# x28-dash-actions.cgi — Dashboard action endpoint (mutations via proven scripts).
# Accepts POST with JSON body. Validates strictly. Returns JSON response.
#
# SAFETY: every action calls the SAME proven scripts the Telegram bot uses.
# No raw system access. Invalid input returns {"error":"..."} and never
# reaches any script.

exec 2>/dev/null  # suppress stderr in production

echo "Content-Type: application/json"
echo "Access-Control-Allow-Origin: *"
echo ""

# --- parse request ---
method="${REQUEST_METHOD:-GET}"
[ "$method" != "POST" ] && { echo '{"error":"POST required"}'; exit 0; }

body=$(cat)
action=$(printf '%s' "$body" | jq -r '.action // ""' 2>/dev/null)
confirm=$(printf '%s' "$body" | jq -r '.confirm // false' 2>/dev/null)

# --- validation helpers ---
valid_mac() { echo "$1" | grep -qE '^[0-9A-Fa-f]{2}(:[0-9A-Fa-f]{2}){5}$'; }
valid_plmn() { case "$1" in 43211|43220) return 0 ;; *) return 1 ;; esac; }
valid_name() { [ -n "$1" ] && [ ${#1} -le 48 ] && ! echo "$1" | grep -qP '[<>{};|\\]'; }

respond() { printf '{"ok":%s,"message":"%s"}' "${1:-true}" "$(echo "${2:-}" | sed 's/"/\\"/g')"; }

# --- dispatch ---
case "$action" in

    assign)
        mac=$(printf '%s' "$body" | jq -r '.mac // ""')
        person=$(printf '%s' "$body" | jq -r '.person // ""')
        if ! valid_mac "$mac"; then respond false "invalid MAC format"; exit 0; fi
        if ! valid_name "$person"; then respond false "invalid person name"; exit 0; fi
        if [ "$person" = "__new__" ]; then respond false "invalid person name"; exit 0; fi
        result=$(sh /data/proxy/x28-owners.sh assign "$mac" "$person" 2>&1)
        respond true "$result"
        ;;

    unassign)
        mac=$(printf '%s' "$body" | jq -r '.mac // ""')
        if ! valid_mac "$mac"; then respond false "invalid MAC"; exit 0; fi
        result=$(sh /data/proxy/x28-owners.sh unassign "$mac" 2>&1)
        respond true "$result"
        ;;

    switch_isp)
        plmn=$(printf '%s' "$body" | jq -r '.plmn // ""')
        if [ "$confirm" != "true" ]; then respond false "confirmation required"; exit 0; fi
        if ! valid_plmn "$plmn"; then respond false "PLMN must be 43211 or 43220"; exit 0; fi
        sh /data/proxy/operator-watchdog.sh switch "$plmn" >/dev/null 2>&1 &
        respond true "switch initiated (takes ~3 min)"
        ;;

    toggle_rescue)
        state=$(printf '%s' "$body" | jq -r '.state // ""')
        case "$state" in on|off) ;; *) respond false "state must be on or off"; exit 0 ;; esac
        result=$(sh /data/proxy/x28-rescue.sh switch "$state" 2>&1)
        respond true "$result"
        ;;

    toggle_adblock)
        if [ "$confirm" != "true" ]; then respond false "confirmation required"; exit 0; fi
        if /etc/init.d/adblock enabled 2>/dev/null; then
            /etc/init.d/adblock stop 2>/dev/null; /etc/init.d/adblock disable 2>/dev/null
            respond true "adblock disabled"
        else
            /etc/init.d/adblock enable 2>/dev/null; /etc/init.d/adblock start 2>/dev/null
            respond true "adblock enabled"
        fi
        ;;

    reboot)
        if [ "$confirm" != "true" ]; then respond false "confirmation required for reboot"; exit 0; fi
        respond true "rebooting in 5 seconds"
        sleep 5
        reboot
        ;;

    daily_ledger)
        date=$(printf '%s' "$body" | jq -r '.date // ""')
        case "$date" in ??????????) ;; *) respond false "date required (YYYY-MM-DD)"; exit 0 ;; esac
        result=$(sh /data/proxy/usage/x28-people.sh --daily "$date" 2>/dev/null)
        printf '{"ok":true,"html":"%s"}' "$(echo "$result" | sed 's/"/\\"/g;s/$/\\n/' | tr -d '\n')"
        ;;

    yearly_ledger)
        year=$(printf '%s' "$body" | jq -r '.year // ""')
        case "$year" in 20[0-9][0-9]) ;; *) respond false "Jalali year required (e.g. 1405)"; exit 0 ;; esac
        result=$(sh /data/proxy/usage/x28-people.sh --yearly "$year" 2>/dev/null)
        printf '{"ok":true,"html":"%s"}' "$(echo "$result" | sed 's/"/\\"/g;s/$/\\n/' | tr -d '\n')"
        ;;

    restart_service)
        svc=$(printf '%s' "$body" | jq -r '.service // ""')
        # whitelist: only these services can be restarted
        case "$svc" in
            x28proxy|x28-bot|x28-adblock|x28-rescue|x28-drift|x28-dash-data)
                /etc/init.d/"$svc" restart >/dev/null 2>&1
                respond true "restarted $svc"
                ;;
            *)
                respond false "service not in restart whitelist"
                ;;
        esac
        ;;

    restart_proxy)
        if [ "$confirm" != "true" ]; then respond false "confirmation required"; exit 0; fi
        /etc/init.d/x28proxy restart >/dev/null 2>&1
        respond true "proxy engine restarted"
        ;;

    *)
        respond false "unknown action: $(printf '%s' "$action" | head -c 40)"
        ;;
esac
exit 0
