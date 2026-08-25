#!/bin/sh
# Spec test: the X28 deploy pipeline owns the complete dashboard stack.
# Derives the required artifact set from what actually exists in the repo
# (frontend, CGI actions, snapshot generator, init services, ledger store)
# and asserts the deploy script installs/enables/restarts every one — so a
# new dashboard file without a deploy step fails here instead of drifting
# on the device (the 2026-08-25 outage class).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
DEPLOY="$HERE/../x28/deploy.sh"
X28DIR="$HERE/../x28"

PASS=0; FAIL=0
assert_contains() { if printf '%s' "$3" | grep -qF "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1 (missing: $2)"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }

[ -f "$DEPLOY" ] || { echo "FAIL - deploy script not found"; echo "PASS=0 FAIL=1"; exit 1; }
MANIFEST=$(cat "$DEPLOY")

# ── every frontend/CGI artifact present in the repo must be deployed ─────────
found=0
for f in "$X28DIR"/dashboard/index.html "$X28DIR"/dashboard/cgi/*.sh; do
    [ -f "$f" ] || continue
    found=$((found+1))
    assert_contains "deploy covers $(basename "$f")" "$(basename "$f")" "$MANIFEST"
done
[ "$found" -ge 7 ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - expected ≥7 dashboard artifacts, found $found"; }

# ── services: both init units installed AND enabled AND restarted ────────────
assert_contains "deploy installs dashboard init"   "x28-dashboard.init" "$MANIFEST"
assert_contains "deploy installs dash-data init"   "x28-dash-data.init" "$MANIFEST"
assert_contains "deploy enables dashboard service" "x28-dashboard enable" "$MANIFEST"
assert_contains "deploy restarts dashboard service" "x28-dashboard restart" "$MANIFEST"
assert_contains "deploy enables dash-data service" "x28-dash-data enable" "$MANIFEST"
assert_contains "deploy restarts dash-data service" "x28-dash-data restart" "$MANIFEST"

# ── supporting pieces: generator, ledger store at canonical path, dirs ───────
assert_contains "deploy pushes snapshot generator" "x28-dash-data.sh" "$MANIFEST"
assert_contains "deploy lands ledger store at canonical path" "/data/proxy/ledger-store.sh" "$MANIFEST"
assert_contains "deploy creates dashboard data dir" "/data/proxy/dashboard/data" "$MANIFEST"
assert_contains "deploy wires www/api symlink" "www/api" "$MANIFEST"

summary
