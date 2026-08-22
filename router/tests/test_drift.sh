#!/bin/sh
# Unit tests: config-drift classifier (hn_drift_classify) + runner flow.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HN_LIB="$HERE/../hnlib.sh"
[ -f "$HN_LIB" ] || HN_LIB="$HERE/hnlib.sh"
. "$HN_LIB"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

H1=1111111111111111111111111111111111111111111111111111111111111111
H2=2222222222222222222222222222222222222222222222222222222222222222
H3=3333333333333333333333333333333333333333333333333333333333333333

printf "%s /a\n%s /b\n" "$H1" "$H2" > "$TMP/cur"
printf "%s /a\n%s /b\n" "$H1" "$H2" > "$TMP/lg"
out=$(hn_drift_classify "$TMP/cur" "$TMP/lg")
assert_eq "classify clean verdict" "V|CLEAN" "$(echo "$out" | grep '^V|')"

# modified
printf "%s /a\n%s /b\n" "$H3" "$H2" > "$TMP/cur2"
out=$(hn_drift_classify "$TMP/cur2" "$TMP/lg")
assert_eq "modified verdict" "V|ALERT" "$(echo "$out" | grep '^V|')"
assert_contains "modified line" "M|/a" "$out"

# added + deleted
printf "%s /a\n%s /c\n" "$H1" "$H3" > "$TMP/cur3"
out=$(hn_drift_classify "$TMP/cur3" "$TMP/lg")
assert_contains "added line" "A|/c" "$out"
assert_contains "deleted line" "D|/b" "$out"
assert_eq "add+del verdict" "V|ALERT" "$(echo "$out" | grep '^V|')"

# SAME-AS-PENDING: cur equals pending set
cp "$TMP/cur3" "$TMP/pend3"
out=$(hn_drift_classify "$TMP/cur3" "$TMP/lg" "$TMP/pend3")
assert_eq "same-as-pending verdict" "V|SAME-AS-PENDING" "$(echo "$out" | grep '^V|')"

# new drift on top of pending → ALERT again
printf "%s /a\n%s /c\n%s /d\n" "$H1" "$H3" "$H2" > "$TMP/cur4"
out=$(hn_drift_classify "$TMP/cur4" "$TMP/lg" "$TMP/pend3")
assert_eq "new drift verdict" "V|ALERT" "$(echo "$out" | grep '^V|')"
assert_contains "new drift line" "A|/d" "$out"

# ── runner flow with fixture file-set (env-seamed) ──────────────────────────
FLOW="$TMP/flow"; mkdir -p "$FLOW"
DRIFT_SH="$HERE/../x28/x28-drift.sh"
DD="$TMP/drift-state"
mkdir -p "$DD/snapshots" 2>/dev/null
echo v1 > "$FLOW/conf.yaml"; echo v1 > "$FLOW/rc.local"
export DRIFT_DIR="$DD" DRIFT_NOTIFY=0 DRIFT_MIN_AGE=0 DRIFT_KEEP=2
export DRIFT_FILES="$FLOW/conf.yaml $FLOW/rc.local"

# baseline run creates last-good, no card
out=$(sh "$DRIFT_SH" run)
[ -f "$DD/last-good.sha" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - baseline last-good missing"; }

# force next run to act despite age gate
echo 0 > "$DD/last-run"

# drift conf.yaml → card printed to stdout (notify off), pending written
echo v2 > "$FLOW/conf.yaml"
out=$(sh "$DRIFT_SH" run)
assert_contains "runner drift alert names file" "M|$FLOW/conf.yaml" "$out"
[ -f "$DD/pending.sha" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - pending not written"; }

# same state again → quiet (SAME-AS-PENDING): no CARD line in output
echo 0 > "$DD/last-run"
out=$(sh "$DRIFT_SH" run)
printf '%s' "$out" | grep -q "CARD:" && { FAIL=$((FAIL+1)); echo "FAIL - repeat alert not suppressed"; } || PASS=$((PASS+1))

# ack advances last-good → subsequent identical run CLEAN and pending cleared
out=$(sh "$DRIFT_SH" ack)
assert_contains "ack card present" "acknowledged" "$out"
[ ! -f "$DD/pending.sha" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - pending not cleared on ack"; }
echo 0 > "$DD/last-run"
out=$(sh "$DRIFT_SH" run)
printf '%s' "$out" | grep -q "CARD:" && { FAIL=$((FAIL+1)); echo "FAIL - alert after ack for same state"; } || PASS=$((PASS+1))

# snapshot ring bounded to DRIFT_KEEP=2
for i in 1 2 3; do echo x$i > "$FLOW/conf.yaml"; echo 0 > "$DD/last-run"; sh "$DRIFT_SH" run >/dev/null; done
n=$(ls "$DD/snapshots"/config-*.tar.gz 2>/dev/null | wc -l)
[ "$n" -le 2 ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - snapshot ring kept $n (>2)"; }

unset DRIFT_DIR DRIFT_NOTIFY DRIFT_MIN_AGE DRIFT_KEEP DRIFT_FILES

summary
