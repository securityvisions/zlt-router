#!/bin/sh
set -eu

LOCK_DIR=/tmp/passwall-health.lock
COUNT_FILE=/tmp/passwall-fail-count
MARKER=/root/.passwall-disabled-by-failopen
DIRECT_CHECK=/tmp/passwall-direct-health-ip
VPN_CHECK=/tmp/passwall-recovery-vpn-ip

mkdir "$LOCK_DIR" 2>/dev/null || exit 0
trap 'rmdir "$LOCK_DIR" 2>/dev/null || true' EXIT INT TERM

[ -e "$MARKER" ] || exit 0
[ "$(uci -q get passwall.@global[0].enabled || true)" != "1" ] || {
  rm -f "$MARKER"
  exit 0
}

# When this fails, the upstream package/link is still unavailable. Stay direct.
if ! wget -q -T 10 -O "$DIRECT_CHECK" https://api.ipify.org ||
   ! grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' "$DIRECT_CHECK"; then
  logger -t passwall-health "auto-recovery paused: direct internet is unavailable"
  exit 0
fi
DIRECT_IP="$(cat "$DIRECT_CHECK")"

NODE="$(uci -q get passwall.@global[0].tcp_node || true)"
[ -n "$NODE" ] || exit 0
mkdir -p /tmp/etc/passwall/bin
ln -sf /usr/bin/sing-box /tmp/etc/passwall/bin/sing-box

NODE_TEST="$(/usr/share/passwall/test.sh url_test_node "$NODE" urltest_node 2>/dev/null || true)"
if ! echo "$NODE_TEST" | grep -Eq '^20[04]:'; then
  logger -t passwall-health "auto-recovery paused: node ${NODE} failed its isolated test"
  exit 0
fi

logger -t passwall-health "direct internet and node are healthy; starting PassWall"
uci set passwall.@global[0].enabled='1'
uci set passwall.@global[0].acl_enable='0'
uci set passwall.@global[0].udp_node='tcp'
uci set passwall.@global[0].use_direct_list="1"
uci commit passwall

# DNSMasq's dynamic nftset points into the PassWall table. Remove that
# reference while PassWall recreates the table; bypass-ensure restores it.
uci -q delete dhcp.@dnsmasq[0].extraconftext || true
uci commit dhcp
/etc/init.d/dnsmasq restart

if ! timeout 90 /etc/init.d/passwall start </dev/null >/tmp/passwall-autorecover-start.log 2>&1; then
  uci set passwall.@global[0].enabled='0'
  uci commit passwall
  /etc/init.d/passwall stop
  uci -q delete dhcp.@dnsmasq[0].extraconftext || true
  uci commit dhcp
  /etc/init.d/dnsmasq restart
  logger -t passwall-health "auto-recovery failed during PassWall start; direct mode restored"
  exit 0
fi

ATTEMPT=0
while [ "$ATTEMPT" -lt 12 ]; do
  ATTEMPT=$((ATTEMPT + 1))
  if pgrep -f '/TCP.*SOCKS.json' >/dev/null 2>&1 &&
     nft list chain inet passwall PSW_NAT 2>/dev/null | grep -q 'redirect to :1041' &&
     nft list chain inet passwall PSW_MANGLE 2>/dev/null | grep -q 'tproxy ip to :1041'; then
    /root/passwall-bypass-ensure.sh >/dev/null 2>&1 || true
    if wget -q -T 12 -O "$VPN_CHECK" https://api.ipify.org &&
       grep -Eq '^[0-9]{1,3}(\.[0-9]{1,3}){3}$' "$VPN_CHECK" &&
       [ "$(cat "$VPN_CHECK")" != "$DIRECT_IP" ]; then
      rm -f "$MARKER" "$COUNT_FILE"
      logger -t passwall-health "auto-recovery succeeded; VPN routing restored"
      [ -f /root/hnlib.sh ] && . /root/hnlib.sh && hn_event_record internet_up "PassWall restarted; VPN routing restored" passwall-autorecover >/dev/null 2>&1 || true
      exit 0
    fi
  fi
  sleep 5
done

uci set passwall.@global[0].enabled='0'
uci commit passwall
/etc/init.d/passwall stop
uci -q delete dhcp.@dnsmasq[0].extraconftext || true
uci commit dhcp
/etc/init.d/dnsmasq restart
logger -t passwall-health "auto-recovery verification failed; direct mode restored"
exit 0
