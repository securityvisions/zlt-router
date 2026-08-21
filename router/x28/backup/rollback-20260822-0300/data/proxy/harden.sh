#!/bin/sh
# harden.sh — restrict the ZLT X28's management ports to the LAN.
#
# Canonical copy lives in this repo (router/x28/harden.sh); it deploys to the
# X28 as /data/proxy/harden.sh and runs at boot from rc.local. Idempotent:
# re-running rebuilds the X28_MGMT chain and the INPUT jump.
#
# Restricts: SSH (22), telnet (23), v2rayA web (2017). Everything on those
# ports from outside the LAN (e.g. the 4G WAN) is dropped. The vendor web
# (80/443) is left to the vendor NAT (not reachable from the WAN anyway).

LAN_SUBNET="${X28_LAN_SUBNET:-192.168.70.0/24}"

# (Re)build the chain.
iptables -N X28_MGMT 2>/dev/null
iptables -F X28_MGMT 2>/dev/null
iptables -A X28_MGMT -i lo -j RETURN
iptables -A X28_MGMT -s "$LAN_SUBNET" -j RETURN
iptables -A X28_MGMT -j DROP

# (Re)hook the INPUT jump (avoid duplicates).
iptables -D INPUT -p tcp -m multiport --dports 22,23,2017 -j X28_MGMT 2>/dev/null
iptables -A INPUT -p tcp -m multiport --dports 22,23,2017 -j X28_MGMT
