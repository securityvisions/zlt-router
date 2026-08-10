#!/bin/sh
# Unit tests for dashboard_body (ticket 05) — the Panel entry summary block
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

body=$(dashboard_body 58 88.2 14 '🟢 UP' 5 '1.20 GB' 74 '14.7M' 0.45 42)
assert_eq "dashboard full" "Data     ▰▰▰▰▰▰▱▱▱▱  58% · 88.2 GB left · 14d
Proxy    🟢 UP
Devices  5 online · 1.20 GB today
Disk     ▰▰▰▰▰▰▰▱▱▱  74% used (14.7M free)
Load     0.45  42°C" "$body"

# Unknown balance (no data yet) → dash placeholder, no day suffix (bd=0 → empty)
body2=$(dashboard_body 0 "" 0 '🔴 DOWN' 0 '—' 10 '5.0M' 1.20 63)
assert_eq "dashboard empty balance" "Data     ▱▱▱▱▱▱▱▱▱▱  0% · — GB left
Proxy    🔴 DOWN
Devices  0 online · — today
Disk     ▰▱▱▱▱▱▱▱▱▱  10% used (5.0M free)
Load     1.20  63°C" "$body2"

summary