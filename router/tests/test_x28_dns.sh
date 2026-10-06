#!/bin/sh
# Unit tests: router/x28/x28-dns.sh
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
DNS_SH="$HERE/../x28/x28-dns.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

CONF="$TMP/dnsmasq.conf"
RESOLV="$TMP/resolv.conf"

cat > "$CONF" <<'EOF'
dhcp-option=br0,option:dns-server,192.168.70.1,114.114.114.114
server=10.201.112.252
EOF

cat > "$RESOLV" <<'EOF'
nameserver 10.201.112.252
EOF

# Test 1: Tunnel mode application
DNSMASQ_CONF="$CONF" sh "$DNS_SH" tunnel >/dev/null 2>&1

if grep -q "server=127.0.0.1#5353" "$CONF" && grep -q "no-resolv" "$CONF"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: tunnel mode not configured in $CONF"
fi

# Test 2: Rogue DHCP secondary stripped
if ! grep -q "114.114.114.114" "$CONF" && grep -q "dhcp-option=br0,option:dns-server,192.168.70.1" "$CONF"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: rogue secondary DNS not stripped"
fi

# Test 3: Idempotency (second run reports already active)
res=$(DNSMASQ_CONF="$CONF" sh "$DNS_SH" tunnel 2>&1)
case "$res" in
    *"already active"*)
        PASS=$((PASS + 1))
        ;;
    *)
        FAIL=$((FAIL + 1))
        echo "FAIL: idempotency check failed: $res"
        ;;
esac

# Test 4: ISP mode switch
res_isp=$(DNSMASQ_CONF="$CONF" sh "$DNS_SH" isp 2>&1)
if grep -q "server=10.201.112.252" "$CONF" && ! grep -q "127.0.0.1#5353" "$CONF"; then
    PASS=$((PASS + 1))
else
    FAIL=$((FAIL + 1))
    echo "FAIL: isp mode switch failed: $res_isp"
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
