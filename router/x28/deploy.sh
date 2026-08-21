#!/bin/bash
# deploy.sh — deploy the X28 smart-edge subsystem to both routers.
#
# Canonical copy lives in this repo (router/x28/deploy.sh). Deploys:
#   X28 (192.168.70.1):  x28lib.sh linkstate.sh harden.sh reselect.sh,
#                        /etc/init.d/x28proxy + real xray-proxy.json (secrets
#                        from X28_PROXY_CONFIG), harden wired into rc.local
#   AX3000T (192.168.1.1): x28lib.sh x28link.sh x28reselect.sh x28watch.sh,
#                        cron entry, PassWall via_x28 node
#
# Credentials come from the environment (never the repo):
#   X28_PASS=...      X28 root password (dropbear, ssh-rsa host key)
#   AX3T_PASS=...     AX3000T root password
#   X28_PROXY_CONFIG=/path/to/xray-proxy.json   (real config with secrets)
# Requires: sshpass (or key-based SSH already set up).

set -eu

HERE=$(cd "$(dirname "$0")" && pwd)
X28_HOST="${X28_HOST:-192.168.70.1}"
AX_HOST="${AX_HOST:-192.168.1.1}"
SSH_OPTS="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o HostKeyAlgorithms=+ssh-rsa"
X28_PASS="${X28_PASS:?set X28_PASS}"
AX3T_PASS="${AX3T_PASS:?set AX3T_PASS}"
X28_PROXY_CONFIG="${X28_PROXY_CONFIG:-}"

ssh_x28()   { sshpass -p "$X28_PASS"  ssh $SSH_OPTS -o PubkeyAuthentication=no "root@$X28_HOST" "$@"; }
ssh_ax()    { sshpass -p "$AX3T_PASS" ssh $SSH_OPTS -o PubkeyAuthentication=no "root@$AX_HOST" "$@"; }
# Push a file over stdin (dropbear has no sftp-server; scp would fail).
push_x28()  { sshpass -p "$X28_PASS"  ssh $SSH_OPTS -o PubkeyAuthentication=no "root@$X28_HOST" "cat > $2" < "$1"; }
push_ax()   { sshpass -p "$AX3T_PASS" ssh $SSH_OPTS -o PubkeyAuthentication=no "root@$AX_HOST" "cat > $2" < "$1"; }

echo "== X28: scripts =="
for f in x28lib.sh linkstate.sh harden.sh reselect.sh x28-health.sh dns-fix.sh \
         tg-notify.sh x28-status.sh x28-boot-alert.sh operator-watchdog.sh x28-bot.sh; do
  push_x28 "$HERE/$f" "/data/proxy/$f"; ssh_x28 "chmod +x /data/proxy/$f"
done

echo "== X28: mihomo engine =="
ssh_x28 "mkdir -p /data/proxy/mihomo"
# config: the repo copy is a PLACEHOLDER template — only seed it when the
# device has no real config (the live one carries real credentials and is
# maintained on the device / via targeted edits, never via this deploy).
ssh_x28 "[ -f /data/proxy/mihomo/config.yaml ] || cat > /data/proxy/mihomo/config.yaml" < "$HERE/mihomo-config.yaml"
ssh_x28 "chmod 600 /data/proxy/mihomo/config.yaml 2>/dev/null; true"
ssh_x28 "[ -f /data/proxy/mihomo/geoip.dat ] || cp /data/proxy/geoip.dat /data/proxy/mihomo/geoip.dat"
ssh_x28 "[ -f /data/proxy/mihomo/geosite.dat ] || cp /data/proxy/geosite.dat /data/proxy/mihomo/geosite.dat"
push_x28 "$HERE/x28proxy.init" /etc/init.d/x28proxy
ssh_x28 "chmod +x /etc/init.d/x28proxy && /etc/init.d/x28proxy restart"

echo "== X28: ad-blocking =="
ssh_x28 "mkdir -p /data/proxy/adblock"
for f in adblock-update.sh adblock-loop.sh; do
  push_x28 "$HERE/$f" "/data/proxy/adblock/$f"; ssh_x28 "chmod +x /data/proxy/adblock/$f"
done
push_x28 "$HERE/x28-adblock.init" /etc/init.d/x28-adblock
ssh_x28 "chmod +x /etc/init.d/x28-adblock && /etc/init.d/x28-adblock enable"
push_x28 "$HERE/x28-bot.init" /etc/init.d/x28-bot
ssh_x28 "chmod +x /etc/init.d/x28-bot && /etc/init.d/x28-bot enable && /etc/init.d/x28-bot restart"

echo "== X28: thermal guard =="
for f in x28-thermal.sh x28-thermal-loop.sh; do push_x28 "$HERE/$f" "/data/proxy/$f"; ssh_x28 "chmod +x /data/proxy/$f"; done
push_x28 "$HERE/x28-thermal.init" /etc/init.d/x28-thermal
ssh_x28 "chmod +x /etc/init.d/x28-thermal && /etc/init.d/x28-thermal enable && /etc/init.d/x28-thermal restart"

echo "== X28: SQM / band / telemetry / tunnel =="
for f in x28-sqm.sh x28-band.sh x28-telemetry.sh x28-tunnel.sh; do push_x28 "$HERE/$f" "/data/proxy/$f"; ssh_x28 "chmod +x /data/proxy/$f"; done
for f in x28-telemetry.init x28-tunnel.init; do push_x28 "$HERE/$f" "/etc/init.d/${f%.init}"; ssh_x28 "chmod +x /etc/init.d/${f%.init} && /etc/init.d/${f%.init} enable && /etc/init.d/${f%.init} start"; done

echo "== X28: usage accounting =="
ssh_x28 "mkdir -p /data/proxy/usage/day /data/proxy/usage/month"
push_x28 "$HERE/usage-collect.sh" /data/proxy/usage/usage-collect.sh
push_x28 "$HERE/x28-usage.sh" /data/proxy/usage/x28-usage.sh
ssh_x28 "chmod +x /data/proxy/usage/usage-collect.sh /data/proxy/usage/x28-usage.sh"
ssh_x28 "[ -f /data/proxy/usage/billing.conf ] || printf 'RATE_FULL=7700\nRATE_FRIDAY=4620\n' > /data/proxy/usage/billing.conf"
push_x28 "$HERE/x28-usage.init" /etc/init.d/x28-usage
ssh_x28 "chmod +x /etc/init.d/x28-usage && /etc/init.d/x28-usage enable && /etc/init.d/x28-usage restart"

echo "== X28: harden at boot =="
ssh_x28 "grep -q '/data/proxy/harden.sh' /etc/rc.local || sed -i 's|^exit 0$|sh /data/proxy/harden.sh\nexit 0|' /etc/rc.local"
ssh_x28 "sh /data/proxy/harden.sh"

echo "== AX3000T: scripts =="
push_ax "$HERE/x28lib.sh" /root/x28lib.sh
push_ax "$HERE/linkstate.sh" /root/x28link.sh
push_ax "$HERE/reselect.sh" /root/x28reselect.sh
push_ax "$HERE/../x28watch.sh" /root/x28watch.sh
ssh_ax "chmod +x /root/x28link.sh /root/x28reselect.sh /root/x28watch.sh"

echo "== AX3000T: cron =="
ssh_ax "grep -q x28watch /etc/crontabs/root || echo '*/5 * * * * /root/x28watch.sh' >> /etc/crontabs/root"

echo "== AX3000T: PassWall via_x28 node =="
push_ax "$HERE/passwall-via-x28.sh" /root/passwall-via-x28.sh
ssh_ax "sh /root/passwall-via-x28.sh"

echo "deploy complete"
