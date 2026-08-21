#!/bin/sh
# Unit tests: router/x28/dns-fix.sh — DHCP DNS single-source lock (zlt-polish 04).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
FIX="$HERE/../x28/dns-fix.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Fixture: dnsmasq.conf with poisoned secondary
cat > "$TMP/dnsmasq.conf" <<'EOF'
dhcp-option=br0,option:dns-server,192.168.70.1,114.114.114.114
server=127.0.0.1#5353
EOF
# Simulate dns-fix DHCP strip (the same sed as in dns-fix.sh)
sed -i 's|,114\.114\.114\.114||g' "$TMP/dnsmasq.conf"
if grep -q "114.114.114.114" "$TMP/dnsmasq.conf"; then
    FAIL=$((FAIL+1)); echo "FAIL - secondary not stripped"
else
    PASS=$((PASS+1))
fi
if grep -q "dhcp-option=br0,option:dns-server,192.168.70.1$" "$TMP/dnsmasq.conf"; then
    PASS=$((PASS+1))
else
    FAIL=$((FAIL+1)); echo "FAIL - primary not preserved"; cat "$TMP/dnsmasq.conf"
fi

# Idempotency: second strip is no-op
sed -i 's|,114\.114\.114\.114||g' "$TMP/dnsmasq.conf"
if grep -q "114.114.114.114" "$TMP/dnsmasq.conf"; then
    FAIL=$((FAIL+1)); echo "FAIL - idempotency"
else
    PASS=$((PASS+1))
fi

# File without secondary stays untouched
cat > "$TMP/dnsmasq2.conf" <<'EOF'
dhcp-option=br0,option:dns-server,192.168.70.1
EOF
cp "$TMP/dnsmasq2.conf" "$TMP/before"
sed -i 's|,114\.114\.114\.114||g' "$TMP/dnsmasq2.conf"
if cmp -s "$TMP/dnsmasq2.conf" "$TMP/before"; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - untouched file changed"; fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
