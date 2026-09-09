#!/bin/bash
# test_resilience_e2e.sh — End-to-end resilience & dual-proxy verification test suite
# Tests both AX3000T (192.168.1.1) and X28 (192.168.70.1)

set -euo pipefail

AX_IP="192.168.1.1"
X28_IP="192.168.70.1"

echo "============================================================"
echo "  DUAL-ROUTER RESILIENCE & AUTO-PORT E2E VERIFICATION"
echo "============================================================"

pass=0
fail=0

assert_eq() {
    local desc="$1"
    local expected="$2"
    local actual="$3"
    if [ "$expected" = "$actual" ]; then
        echo "  [PASS] $desc"
        pass=$((pass + 1))
    else
        echo "  [FAIL] $desc (expected: '$expected', got: '$actual')"
        fail=$((fail + 1))
    fi
}

# 1. Test AX3000T domestic direct routing
code=$(curl.exe -s --noproxy '*' --interface 192.168.1.223 -m 10 -o /dev/null -w "%{http_code}" "https://www.digikala.com" 2>/dev/null || echo "000")
assert_eq "AX3000T domestic traffic (Digikala) flows direct" "200" "$code"

# 1b. Test AX3000T .ir domain direct routing (pirategames.ir on foreign CDN edge)
code=$(curl.exe -s --noproxy '*' --interface 192.168.1.223 -m 10 -o /dev/null -w "%{http_code}" "https://www.pirategames.ir/online/remnant-ii/" 2>/dev/null || echo "000")
assert_eq "AX3000T .ir domain traffic (pirategames.ir) flows direct" "200" "$code"

# 2. Test AX3000T transparent circumvention (Google)
code=$(curl.exe -s --noproxy '*' --interface 192.168.1.223 -m 10 -o /dev/null -w "%{http_code}" "https://www.google.com" 2>/dev/null || echo "000")
assert_eq "AX3000T circumvention traffic (Google) flows via VPS" "200" "$code"

# 3. Test AX3000T transparent circumvention (YouTube)
code=$(curl.exe -s --noproxy '*' --interface 192.168.1.223 -m 10 -o /dev/null -w "%{http_code}" "https://www.youtube.com" 2>/dev/null || echo "000")
assert_eq "AX3000T circumvention traffic (YouTube) flows via VPS" "200" "$code"

# 4. Test X28 independent SOCKS proxy (Google)
code=$(curl.exe -s --noproxy '*' -m 10 -x "socks5h://$X28_IP:1080" -o /dev/null -w "%{http_code}" "https://www.google.com" 2>/dev/null || echo "000")
assert_eq "X28 independent proxy (Google) is operational" "200" "$code"

# 5. Test X28 independent SOCKS proxy (YouTube)
code=$(curl.exe -s --noproxy '*' -m 10 -x "socks5h://$X28_IP:1080" -o /dev/null -w "%{http_code}" "https://www.youtube.com" 2>/dev/null || echo "000")
assert_eq "X28 independent proxy (YouTube) is operational" "200" "$code"

# 6. Test X28 independent proxy .ir domain direct routing (pirategames.ir)
code=$(curl.exe -s --noproxy '*' -m 10 -x "socks5h://$X28_IP:1080" -o /dev/null -w "%{http_code}" "https://www.pirategames.ir/online/remnant-ii/" 2>/dev/null || echo "000")
assert_eq "X28 independent proxy .ir domain (pirategames.ir) flows direct" "200" "$code"

echo "============================================================"
echo "  RESULTS: $pass passed, $fail failed"
echo "============================================================"

[ "$fail" -eq 0 ]
