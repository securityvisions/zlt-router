#!/bin/sh
# Unit tests: WiFi share URI builder
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
SH="$HERE/../x28/x28-wifi.sh"
PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
assert_contains() { if printf '%s' "$3" | grep -q "$2"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  should contain: [%s]\n' "$2"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

# Simple SSID/PASS
cat > "$TMP/wifi.conf" <<'EOF'
ssid=MyWiFi
psk=Secret123
EOF
out=$(WIFI_CONF="$TMP/wifi.conf" sh "$SH" uri 2>&1)
assert_eq "wifi uri simple" "WIFI:S:MyWiFi;T:WPA;P:Secret123;;" "$out"
# Escaping
cat > "$TMP/wifi.conf" <<'EOF'
ssid=My;WiFi:Test
psk=P@ss;word:
EOF
out=$(WIFI_CONF="$TMP/wifi.conf" sh "$SH" uri 2>&1)
assert_eq "wifi uri escape" "WIFI:S:My\;WiFi\:Test;T:WPA;P:P@ss\;word\:;;" "$out"
# Open network (no psk)
cat > "$TMP/wifi.conf" <<'EOF'
ssid=OpenNet
EOF
out=$(WIFI_CONF="$TMP/wifi.conf" sh "$SH" uri 2>&1)
assert_eq "wifi uri open" "WIFI:S:OpenNet;T:nopass;;" "$out"
# Missing file
out=$(WIFI_CONF="$TMP/nonexist" sh "$SH" uri 2>&1); rc=$?
if [ $rc -ne 0 ]; then PASS=$((PASS+1)); else echo "FAIL - missing file should fail"; FAIL=$((FAIL+1)); fi
# Card
cat > "$TMP/wifi.conf" <<'EOF'
ssid=MyWiFi
psk=Secret123
EOF
out=$(WIFI_CONF="$TMP/wifi.conf" sh "$SH" card 2>&1)
assert_contains "wifi card ssid" "MyWiFi" "$out"
# Missing card
out=$(WIFI_CONF="$TMP/nonexist" sh "$SH" card 2>&1)
assert_contains "wifi card missing" "not provisioned" "$out"

summary
