#!/bin/sh
# Unit tests: Weekly Digest
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
PASS=0; FAIL=0
assert_contains() { if printf '%s' "$3" | grep -q "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  should contain: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

SH="$HERE/../x28/x28-digest.sh"
# Setup fixtures
mkdir -p "$TMP/usage/day"
for i in 0 1 2; do
  d=$(date -d "$i days ago" +%F)
  echo "aa:bb:cc:dd:ee:ff|192.168.70.100|Phone|1073741824|0" > "$TMP/usage/day/$d"
done
cat > "$TMP/balance_report" <<'EOF'
📦 Samantel — 10 GB left across 1 plan(s)
Main: 150 GB · 10 GB left (6%) · expires 2026-09-01 (~10d)
Drain ~1 GB/day → ~10d left
EOF
# Mock outage ledger with no outages
: > "$TMP/outage.log"
# Run digest with env overrides
out=$(USAGE_DIR="$TMP/usage" HN_OUTAGE_LEDGER="$TMP/outage.log" BALANCE_REPORT="$TMP/balance_report" TELEMETRY_LOG="/dev/null" sh "$SH" 2>&1)
assert_contains "digest header" "Weekly Digest" "$out"
assert_contains "digest usage" "Usage" "$out"
assert_contains "digest balance" "balance" "$out"
assert_contains "digest week range" "week" "$out"
# Test with empty usage dir
out2=$(USAGE_DIR="$TMP/empty" HN_OUTAGE_LEDGER="$TMP/outage.log" BALANCE_REPORT="$TMP/balance_report" sh "$SH" 2>&1)
assert_contains "digest empty usage fallback" "Weekly Digest" "$out2"

summary
