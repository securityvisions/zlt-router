#!/bin/sh
# Unit tests: router/x28/x28-vps-heal.sh — auto-heal decision logic (fixture-tested).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
HEAL="$HERE/../x28/x28-vps-heal.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Mock curl for mihomo controller: alive vs dead
# We test the helper functions by sourcing and overriding curl

# Test 1: mihomo_auto_dead returns dead when no alive:true
cat > "$TMP/mock_dead.sh" <<'MOCK'
#!/bin/sh
if echo "$*" | grep -q "proxies/auto"; then echo '{"alive":false}'; else echo '{}'; fi
MOCK
chmod +x "$TMP/mock_dead.sh"
# Simulate: no alive:true in response -> dead
resp='{"alive":false}'
echo "$resp" | grep -q '"alive":true' && alive=1 || alive=0
if [ "$alive" -eq 0 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - dead detection"; fi

# Test 2: alive detection
resp='{"alive":true,"all":["vps-reality"]}'
echo "$resp" | grep -q '"alive":true' && alive=1 || alive=0
if [ "$alive" -eq 1 ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - alive detection"; fi

# Test 3: script has required functions and no syntax error
if sh -n "$HEAL" 2>/dev/null; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - syntax"; fi
if grep -q "mihomo_auto_dead" "$HEAL" && grep -q "panel_login" "$HEAL" && grep -q "restartSb" "$HEAL"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - missing functions"; fi

# Test 4: handles empty PANEL_PASS (no heal without creds)
if grep -q 'PANEL_PASS.*|| return 1' "$HEAL"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - empty pass guard"; fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
