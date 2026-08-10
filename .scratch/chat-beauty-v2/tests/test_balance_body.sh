#!/bin/sh
# Unit tests for balance_body (ticket 05) — gauge + plan + trend + drain block
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

body=$(balance_body 58 88.2 150 2027-08-05 '~359d' '~4.47 GB/day → ~19d left' '143.6|143.5|143.5|143.4|143.4|143.4|143.4|143.3|142.9|141.9|141.4|119.5|109.0|88.4')
assert_eq "balance body full" "Gauge    ▰▰▰▰▰▰▱▱▱▱   58% · 88.2 GB left
Plan     150 GB · expires 2027-08-05 (~359d)
Trend    ███████████▅▄▁  last 14d
Drain    ~4.47 GB/day → ~19d left" "$body"

# Drain absent → no Drain line; short series → short trend
body2=$(balance_body 100 150 150 2027-08-05 '~359d' '' '146.5|146.1')
assert_eq "balance body no drain" "Gauge    ▰▰▰▰▰▰▰▰▰▰   100% · 150 GB left
Plan     150 GB · expires 2027-08-05 (~359d)
Trend    █▁  last 2d" "$body2"

# Flat/single series trend
body3=$(balance_body 50 80 150 2027-08-05 '~359d' '' '88')
assert_eq "balance body single point" "Gauge    ▰▰▰▰▰▱▱▱▱▱   50% · 80 GB left
Plan     150 GB · expires 2027-08-05 (~359d)
Trend    ▄  last 1d" "$body3"

summary