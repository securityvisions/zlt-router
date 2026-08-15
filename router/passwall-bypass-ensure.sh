#!/bin/sh
set -eu

# PassWall recreates its nftables table during health recovery. Do not let
# the minute cron job attach DNSMasq nftsets until that transaction finishes.
[ -d /tmp/passwall-health.lock ] && exit 0
[ "$(uci -q get passwall.@global[0].enabled || true)" = "1" ] || exit 0

TABLE=passwall
DIRECT_IP=/usr/share/passwall/rules/direct_ip
DIRECT_HOST=/usr/share/passwall/rules/direct_host
NFT_BATCH=/tmp/codex-bypass.nft
CREATED=0

nft list table inet "$TABLE" >/dev/null 2>&1 || exit 0

if ! nft list set inet "$TABLE" codex_direct4 >/dev/null 2>&1; then
  {
    echo 'add set inet passwall codex_direct4 { type ipv4_addr; flags interval; auto-merge; }'
    printf 'add element inet passwall codex_direct4 { '
    awk '
      index($0, ":") == 0 && $0 ~ /^[0-9]/ {
        sub(/[[:space:]]*#.*/, "")
        gsub(/[[:space:]]/, "")
        if ($0 ~ /^[0-9.]+\/[0-9]+$/) {
          if (count++) printf ", "
          printf "%s", $0
        }
      }
      END { print " }" }
    ' "$DIRECT_IP"
    echo 'add set inet passwall codex_direct6 { type ipv6_addr; flags interval; auto-merge; }'
    printf 'add element inet passwall codex_direct6 { '
    awk '
      index($0, ":") > 0 {
        sub(/[[:space:]]*#.*/, "")
        gsub(/[[:space:]]/, "")
        if ($0 ~ /\//) {
          if (count++) printf ", "
          printf "%s", $0
        }
      }
      END { print " }" }
    ' "$DIRECT_IP"
  } > "$NFT_BATCH"

  nft -f "$NFT_BATCH"

  nft insert rule inet passwall PSW_NAT \
    ip daddr @codex_direct4 counter return comment '"CODEX_DIRECT"'
  nft insert rule inet passwall PSW_MANGLE \
    ip daddr @codex_direct4 counter return comment '"CODEX_DIRECT"'
  nft insert rule inet passwall PSW_OUTPUT_NAT \
    ip daddr @codex_direct4 counter return comment '"CODEX_DIRECT"'
  nft insert rule inet passwall PSW_OUTPUT_MANGLE \
    ip daddr @codex_direct4 counter return comment '"CODEX_DIRECT"'
  nft insert rule inet passwall PSW_MANGLE_V6 \
    ip6 daddr @codex_direct6 counter return comment '"CODEX_DIRECT"'
  nft insert rule inet passwall PSW_OUTPUT_MANGLE_V6 \
    ip6 daddr @codex_direct6 counter return comment '"CODEX_DIRECT"'
  CREATED=1
fi

DOMAINS="$(
  awk '
    /^[[:space:]]*#/ { next }
    {
      sub(/[[:space:]]*#.*/, "")
      gsub(/^[[:space:]]+|[[:space:]]+$/, "")
      if ($0 ~ /^([A-Za-z0-9_-]+\.)+[A-Za-z0-9_-]+$/) {
        if (count++) printf "/"
        printf "%s", $0
      }
    }
  ' "$DIRECT_HOST"
)"
EXTRA="nftset=/${DOMAINS}/4#inet#passwall#codex_direct4,6#inet#passwall#codex_direct6"
OLD="$(uci -q get dhcp.@dnsmasq[0].extraconftext || true)"

if [ "$OLD" != "$EXTRA" ]; then
  uci set dhcp.@dnsmasq[0].extraconftext="$EXTRA"
  uci commit dhcp
  CREATED=1
fi

if [ "$CREATED" = "1" ]; then
  /etc/init.d/dnsmasq restart
  logger -t codex-bypass "Steam, Meet and direct-domain nftsets installed"
fi
