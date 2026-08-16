#!/bin/sh
# deploy.sh — build the Xirouter NOC SPA and sync dist/ to the router's /www.
#
# The web dashboard is a static build served same-origin by the AX3000T's
# uhttpd from /www (the Router API lives at /cgi-bin/routerapi.sh on the same
# origin, so no CORS). Run from web/:  sh deploy.sh
#
# Router reachable via the shared X28 login alias (see router/x28/README.md).

set -eu

HOST="${NOC_DEPLOY_HOST:-root@192.168.1.1}"
REMOTE_DIR="${NOC_REMOTE_DIR:-/www/noc}"

npm run build

# Clear the previous build then copy the fresh one. SSH flags mirror the
# router access convention (ssh-rsa legacy host key, password auth via sshpass
# when present).
ssh_opts="-o HostKeyAlgorithms=+ssh-rsa -o PubkeyAuthentication=no -o StrictHostKeyChecking=accept-new"
if command -v sshpass >/dev/null 2>&1; then
    sshpass -p "$AX3000T_PASSWORD" ssh $ssh_opts "$HOST" "rm -rf $REMOTE_DIR && mkdir -p $REMOTE_DIR" &&
        sshpass -p "$AX3000T_PASSWORD" scp $ssh_opts -r dist/* "$HOST:$REMOTE_DIR/"
else
    ssh $ssh_opts "$HOST" "rm -rf $REMOTE_DIR && mkdir -p $REMOTE_DIR" &&
        scp $ssh_opts -r dist/* "$HOST:$REMOTE_DIR/"
fi

echo "deployed to ${HOST}:${REMOTE_DIR}"
