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
for f in x28lib.sh linkstate.sh harden.sh reselect.sh; do
  push_x28 "$HERE/$f" "/data/proxy/$f"; ssh_x28 "chmod +x /data/proxy/$f"
done

echo "== X28: crypto engine =="
if [ -n "$X28_PROXY_CONFIG" ] && [ -f "$X28_PROXY_CONFIG" ]; then
  ssh_x28 "mkdir -p /data/proxy/sing-box"
  push_x28 "$X28_PROXY_CONFIG" /data/proxy/sing-box/xray-proxy.json
  ssh_x28 "chmod 600 /data/proxy/sing-box/xray-proxy.json"
fi
push_x28 "$HERE/x28proxy.init" /etc/init.d/x28proxy
ssh_x28 "chmod +x /etc/init.d/x28proxy && /etc/init.d/x28proxy enable && /etc/init.d/x28proxy restart"

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
