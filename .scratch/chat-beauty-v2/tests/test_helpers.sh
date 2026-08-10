#!/bin/sh
# Unit tests for the rendering core (ticket 01) — helpers in botlib.sh
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

# ── bar ─────────────────────────────────────────────────────────────────────
assert_eq "bar 0"       "▱▱▱▱▱▱▱▱▱▱" "$(bar 0)"
assert_eq "bar 50"      "▰▰▰▰▰▱▱▱▱▱" "$(bar 50)"
assert_eq "bar 59"      "▰▰▰▰▰▰▱▱▱▱" "$(bar 59)"
assert_eq "bar 100"     "▰▰▰▰▰▰▰▰▰▰" "$(bar 100)"
assert_eq "bar -20"     "▱▱▱▱▱▱▱▱▱▱" "$(bar -20)"
assert_eq "bar 150"     "▰▰▰▰▰▰▰▰▰▰" "$(bar 150)"
assert_eq "bar 23 w14"  "▰▰▰▱▱▱▱▱▱▱▱▱▱▱" "$(bar 23 14)"

# ── spark ───────────────────────────────────────────────────────────────────
assert_eq "spark series" "██▅▂▁" "$(spark '146|146|120|100|88')"
assert_eq "spark flat"   "▄▄▄"    "$(spark '88|88|88')"
assert_eq "spark single" "▄"      "$(spark '88')"
assert_empty "spark empty" "$(spark '')"

# ── pad ─────────────────────────────────────────────────────────────────────
assert_eq "pad left" "abc     " "$(pad abc 8)"
assert_eq "pad long" "longest"  "$(pad longest 4)"

# ── temp_badge ──────────────────────────────────────────────────────────────
assert_eq "badge cool"    "🟢" "$(temp_badge 42)"
assert_eq "badge warm"    "🟠" "$(temp_badge 70)"
assert_eq "badge hot"     "🔴" "$(temp_badge 92)"
assert_empty "badge unknown" "$(temp_badge '')"

# ── dev_usage_rows ──────────────────────────────────────────────────────────
rows=$(printf 'A|0|1073741824\nB|0|536870912\nC|0|0\n' | dev_usage_rows)
assert_eq "dev rows scaled" "A                ▰▰▰▰▰▰▰▰▰▰     1.00 GB
B                ▰▰▰▰▰▱▱▱▱▱     0.50 GB
C                ▱▱▱▱▱▱▱▱▱▱     0.00 GB" "$rows"
assert_empty "dev rows empty" "$(printf '' | dev_usage_rows)"

# ── esc ─────────────────────────────────────────────────────────────────────
assert_eq "esc amp" "a&amp;b" "$(esc 'a&b')"
assert_eq "esc lt"  "&lt;"   "$(esc '<')"
assert_eq "esc gt"  "&gt;"   "$(esc '>')"

# ── card ────────────────────────────────────────────────────────────────────
assert_eq "card anatomy" "<b>Hi</b>
──────────────
<pre>line</pre>" "$(card '<b>Hi</b>' 'line')"

summary