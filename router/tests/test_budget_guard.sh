#!/bin/sh
# Unit tests: Budget Guardian — tier decision and card.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
. "$HN_LIB"
[ -f "$HERE/../ledger-rules.sh" ] && . "$HERE/../ledger-rules.sh"
BUDGET_SH="$HERE/../x28/x28-budget.sh"

PASS=0; FAIL=0
assert_eq() {
    if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi
}
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }

TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# ── hn_budget_tier ──────────────────────────────────────────────────────────
assert_eq "exhausted <0.05" "exhausted" "$(hn_budget_tier 0.04 100 100)"
assert_eq "exhausted not when 0.06" "urgent" "$(hn_budget_tier 0.06 100 100)"
assert_eq "urgent remain <3" "urgent" "$(hn_budget_tier 2.9 100 100)"
assert_eq "urgent days <3" "urgent" "$(hn_budget_tier 100 2 100)"
assert_eq "urgent proj <7" "urgent" "$(hn_budget_tier 100 100 6.9)"
assert_eq "boundary 3 not urgent -> warn" "warn" "$(hn_budget_tier 3 100 100)"
# At exactly 3, should be urgent per <3? Actually spec says <3, so 3 is not <3, but we treat <3 as urgent; 3 should be urgent? Our impl uses <3 for urgent, so 3 is not <3, but test expects urgent at 3 per earlier logic? We used <3, but earlier test expects urgent at 3. Check impl: we use r<3, so 3 not urgent, would be warn. Let's check: remain 3 should be urgent? Ticket says <3, so 3 is not <3, should be warn if other thresholds. But we earlier said urgent at 3. Let's keep <3 strict: 3 should be warn if days/proj large. So adjust test: 2.9 urgent, 3 warn (if not urgent). We'll keep strict.
assert_eq "warn remain <10" "warn" "$(hn_budget_tier 9.9 100 100)"
assert_eq "warn days <7" "warn" "$(hn_budget_tier 100 6 100)"
assert_eq "warn proj <14" "warn" "$(hn_budget_tier 100 100 13.9)"
assert_eq "ok above all" "ok" "$(hn_budget_tier 100 100 100)"
assert_eq "ok empty" "ok" "$(hn_budget_tier "" "" "")"
assert_eq "exhausted priority over urgent" "exhausted" "$(hn_budget_tier 0.01 1 1)"

# ── budget card with fixture balance report ────────────────────────────────
cat > "$TMP/balance_report" <<'EOF'
📦 Samantel — 146.5 GB left across 1 plan(s)
Main: 150 GB · 9.5 GB left (6%) · expires 2026-09-01 (~10d)
+1 expired plan(s)

Drain ~3.5 GB/day → ~2d left (est. — ISP updates slowly)
EOF

export BALANCE_REPORT="$TMP/balance_report"
export BUDGET_STATE="$TMP/budget.state"
export HN_LIB="$HN_LIB"

# Mock date to fix exhaustion date for deterministic test
# Use a wrapper that returns fixed greg date for +2 days
mkdir -p "$TMP/bin"
cat > "$TMP/bin/date" <<'EOS'
#!/bin/sh
if [ "$1" = "-d" ]; then
  # +2 days from fixed today 2026-08-22 => 2026-08-24
  echo "2026-08-24"
else
  echo "2026-08-22"
fi
EOS
chmod +x "$TMP/bin/date"
export DATE_CMD="$TMP/bin/date"
# Also ensure hn_greg_to_jalali works for 2026-08-24
# 2026-08-24 is 1405-06-02 (we know 08-23 is 06-01)
card=$(sh "$BUDGET_SH" --card 2>/dev/null)
echo "$card" | grep -q "remaining 9.5 GB" || { echo "FAIL - card remaining"; FAIL=$((FAIL+1)); }
echo "$card" | grep -q "expires 2026-09-01" || { echo "FAIL - card expires"; FAIL=$((FAIL+1)); }
echo "$card" | grep -q "drain 3.5 GB/day" || { echo "FAIL - card drain"; echo "$card"; FAIL=$((FAIL+1)); }
# 9.5 GB with 3.5/day => 2.7d, tier urgent (proj <7 takes precedence over warn)
echo "$card" | grep -q "urgent" || { echo "FAIL - card tier urgent"; echo "$card"; FAIL=$((FAIL+1)); }
PASS=$((PASS+3))

# Urgent case: 2 GB left
cat > "$TMP/balance_report" <<'EOF'
📦 Samantel — 2 GB left across 1 plan(s)
Main: 150 GB · 2 GB left (1%) · expires 2026-09-01 (~10d)

Drain ~1 GB/day → ~2d left
EOF
card=$(sh "$BUDGET_SH" --card 2>/dev/null)
echo "$card" | grep -q "urgent" || { echo "FAIL - urgent tier"; FAIL=$((FAIL+1)); } 
PASS=$((PASS+1))

# Exhausted
cat > "$TMP/balance_report" <<'EOF'
📦 Samantel — 0.04 GB left across 1 plan(s)
Main: 150 GB · 0.04 GB left (0%) · expires 2026-09-01 (~10d)

Drain ~1 GB/day → ~0d left
EOF
card=$(sh "$BUDGET_SH" --card 2>/dev/null)
echo "$card" | grep -q "exhausted" || { echo "FAIL - exhausted tier"; echo "$card"; FAIL=$((FAIL+1)); }
PASS=$((PASS+1))

# No data
cat > "$TMP/balance_report" <<'EOF'
No data packages found.
EOF
card=$(sh "$BUDGET_SH" --card 2>/dev/null)
echo "$card" | grep -q "no data" || { echo "FAIL - no data card"; FAIL=$((FAIL+1)); }
PASS=$((PASS+1))

# Cooldown: warn should not alert twice within cooldown
cat > "$TMP/balance_report" <<'EOF'
📦 Samantel — 9.5 GB left across 1 plan(s)
Main: 150 GB · 9.5 GB left (6%) · expires 2026-09-01 (~10d)

Drain ~3.5 GB/day → ~2d left
EOF
: > "$TMP/budget.state"
# first check should produce output (would send)
out1=$(BALANCE_REPORT="$TMP/balance_report" BUDGET_STATE="$TMP/budget.state" HN_LIB="$HN_LIB" DATE_CMD="$TMP/bin/date" sh "$BUDGET_SH" --check 2>&1)
# second immediate check should be suppressed (no output, cooldown)
out2=$(BALANCE_REPORT="$TMP/balance_report" BUDGET_STATE="$TMP/budget.state" HN_LIB="$HN_LIB" DATE_CMD="$TMP/bin/date" sh "$BUDGET_SH" --check 2>&1)
if [ -n "$out1" ] && [ -z "$out2" ]; then PASS=$((PASS+1)); else echo "FAIL - cooldown warn"; echo "out1=[$out1]"; echo "out2=[$out2]"; FAIL=$((FAIL+1)); fi

# Exhausted bypasses cooldown
cat > "$TMP/balance_report" <<'EOF'
📦 Samantel — 0.04 GB left across 1 plan(s)
Main: 150 GB · 0.04 GB left (0%) · expires 2026-09-01 (~10d)

Drain ~1 GB/day → ~0d left
EOF
: > "$TMP/budget.state"
# Even if we stamp exhausted, it should still send because cooldown 0
out1=$(BALANCE_REPORT="$TMP/balance_report" BUDGET_STATE="$TMP/budget.state" HN_LIB="$HN_LIB" DATE_CMD="$TMP/bin/date" sh "$BUDGET_SH" --check 2>&1)
out2=$(BALANCE_REPORT="$TMP/balance_report" BUDGET_STATE="$TMP/budget.state" HN_LIB="$HN_LIB" DATE_CMD="$TMP/bin/date" sh "$BUDGET_SH" --check 2>&1)
if [ -n "$out1" ] && [ -n "$out2" ]; then PASS=$((PASS+1)); else echo "FAIL - exhausted bypass"; FAIL=$((FAIL+1)); fi

summary
