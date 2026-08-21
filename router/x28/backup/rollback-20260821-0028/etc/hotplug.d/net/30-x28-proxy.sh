#!/bin/sh
# Re-apply the X28 transparent proxy + clean-DNS override whenever the
# network comes up. The vendor's lan_mgr regenerates /tmp/dnsmasq.conf on
# network/operator changes, which wipes our DNS override — so we re-apply
# here on every net-up event. Idempotent and safe to run repeatedly.
[ "$ACTION" = add ] || exit 0

# Only re-apply after network is usable (modem up). Short delay to let
# dnsmasq/xray settle before we poke them.
sleep 3

# Transparent proxy iptables rules (idempotent)
sh /data/proxy/tproxy-fixed-enable.sh 2>/dev/null || true

# Clean-DNS override (idempotent)
sh /data/proxy/dns-fix.sh 2>/dev/null || true
