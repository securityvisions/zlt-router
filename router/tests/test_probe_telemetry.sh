#!/bin/sh
# Unit tests: probe-service + telemetry-store deep seams (arch-link-probe-telemetry 02+03).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# ── probe-service ─────────────────────────────────────────────────────────────
PS="$HERE/../x28/probe-service.sh"
sh -n "$PS" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - probe-service syntax"; }
grep -q "probe_profile_get" "$PS" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - probe_profile_get missing"; }
grep -q "probe_check_data" "$PS" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - probe_check_data missing (watchdog contract)"; }

# profile dispatch: vps has no socks, link has default socks
spec=$(PROBE_URL="http://x" sh "$PS" profiles 2>/dev/null | grep "^link:")
echo "$spec" | grep -q "127.0.0.1:1070" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - link default socks"; }
spec=$(sh "$PS" profiles 2>/dev/null | grep "^vps:")
echo "$spec" | grep -q "2095" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - vps panel url"; }

# ── telemetry-store ───────────────────────────────────────────────────────────
TS="$HERE/../x28/telemetry-store.sh"
sh -n "$TS" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - telemetry-store syntax"; }

# append/prune with fixture log
export TELEMETRY_LOG="$TMP/tel.log"
. "$TS"
i=0
while [ $i -lt 12 ]; do
    telemetry_append "2026-08-21T0$i:00:00|100|50|vps-reality|MCI|-77|60|1.0"
    i=$((i+1))
done
n=$(wc -l < "$TELEMETRY_LOG")
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 expect [$2] actual [$3]"; fi; }
assert_eq "12 rows appended" "12" "$n"

telemetry_prune 5
n=$(wc -l < "$TELEMETRY_LOG")
assert_eq "pruned to 5" "5" "$n"

# series returns N rows
s=$(telemetry_series 3)
rows=$(printf '%s\n' "$s" | wc -l)
assert_eq "series 3 rows" "3" "$rows"

# quality_series projects ts|f9|f10|f11
q=$(telemetry_quality_series 3)
first=$(printf '%s\n' "$q" | head -1)
fields=$(printf '%s\n' "$first" | awk -F'|' '{print NF}')
assert_eq "quality series fields" "4" "$fields"

# last_age is numeric
age=$(telemetry_last_age)
case "$age" in *[!0-9]*) FAIL=$((FAIL+1)); echo "FAIL - last_age not numeric [$age]";; *) PASS=$((PASS+1));; esac

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
