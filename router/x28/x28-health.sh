#!/bin/sh
# x28-health.sh — one command answering "is the X28 still fully working?"
# The pre/post gate every x28-brain-promotion deploy runs. Read-only: checks,
# never fixes. Prints one PASS/FAIL line per check; exits nonzero on any FAIL.
#
# Canonical copy: router/x28/x28-health.sh — deploys to /data/proxy/x28-health.sh.

fails=0
ck() {  # ck <name> <ok:0|1> [detail]
    if [ "$2" = "0" ]; then echo "PASS $1${3:+ ($3)}"; else echo "FAIL $1${3:+ ($3)}"; fails=$((fails+1)); fi
}

# 1. DNS chain: dnsmasq answers with a known upstream mode (tunnel or
#    isp-fallback — dns-fix picks per tunnel health; both are "working")
dns_ip=$(nslookup google.com 127.0.0.1 2>/dev/null | awk '/^Address [0-9]*:/{print $NF}' | grep -E '^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$' | head -1)
if [ -z "$dns_ip" ]; then
    ck dns_chain 1 "answer=none"
elif grep -q 'server=127.0.0.1#5353' /tmp/dnsmasq.conf 2>/dev/null; then
    ck dns_chain 0 "resolved=$dns_ip mode=tunnel"
elif grep -qE '^server=(10|217)\.' /tmp/dnsmasq.conf 2>/dev/null; then
    ck dns_chain 0 "resolved=$dns_ip mode=isp-fallback (VPS down)"
else
    ck dns_chain 1 "resolved=$dns_ip mode=UNKNOWN (no upstream line)"
fi

# 2. Proxied path: a fetch through the SOCKS crypto engine -> VPS egress
code=$(curl -s -m 12 -x socks5h://192.168.70.1:1080 -o /dev/null -w '%{http_code}' https://www.instagram.com/ 2>/dev/null)
[ "$code" = "200" ] && ck proxied_path 0 "HTTP $code" || ck proxied_path 1 "HTTP ${code:-none}"

# 3. Direct path: the exempted host answers without the proxy
code=$(curl -s -m 12 -o /dev/null -w '%{http_code}' http://berlin.saymyname.website/ 2>/dev/null)
[ "$code" = "200" ] && ck direct_path 0 "HTTP $code" || ck direct_path 1 "HTTP ${code:-none}"

# 4. Transparent-proxy iptables chains exist and redirect TCP
if iptables -t nat -S X28_SPLIT 2>/dev/null | grep -q 'REDIRECT --to-ports 12345'; then
    ck tproxy_chain 0 "X28_SPLIT redirects tcp -> 12345"
else
    ck tproxy_chain 1 "X28_SPLIT missing/incomplete"
fi
if iptables -t mangle -S X28_NOQUIC 2>/dev/null | grep -q 'DROP'; then
    ck quic_block 0 "X28_NOQUIC drops udp/443"
else
    ck quic_block 1 "X28_NOQUIC missing/incomplete"
fi

# 5. Core services alive (mihomo is the proxy engine; v2raya may run its own
#    xray child — that must NOT satisfy this check)
pidof mihomo >/dev/null 2>&1 && ck xray_core 0 "mihomo running" || ck xray_core 1 "mihomo not running"
pgrep -f 'operator-watchdog' >/dev/null 2>&1 && ck op_watchdog 0 "running" || ck op_watchdog 1 "not running"
pidof v2raya >/dev/null 2>&1 && ck v2raya 0 "running" || ck v2raya 1 "not running"

echo "----"
if [ "$fails" = "0" ]; then echo "HEALTH: GREEN (all checks passed)"; exit 0
else echo "HEALTH: RED ($fails check(s) failed)"; exit 1; fi
