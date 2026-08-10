#!/bin/sh
# Unit tests for alert_text (ticket 06) — alert Card anatomy
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

assert_eq "alert device" "📱 New Device
──────────────
Nothing-Phone-2 (192.168.1.126)" "$(alert_text '📱 New Device' 'Nothing-Phone-2 (192.168.1.126)')"

assert_eq "alert balance" "🔶 Samantel notice
──────────────
89 GB left (59%), ~20d at current rate." "$(alert_text '🔶 Samantel notice' '89 GB left (59%), ~20d at current rate.')"

summary