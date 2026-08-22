#!/bin/sh
# sb-selfheal-install.sh — install the VPS-LOCAL sing-box self-heal timer.
# Run ON THE VPS once SSH access is available (today it is publickey-only and
# no key is installed; until then the X28-side heal loop at 4 min and the
# workstation-vantage watcher cover the gap).
#
# Installs /usr/local/sbin/sb-selfheal.sh + a systemd timer checking every
# minute: core process alive AND :443 answering locally, else systemctl
# restart of the s-ui unit; crash-loop capped at 3/15 min.
set -eu

[ "$(id -u)" = "0" ] || { echo "run as root"; exit 1; }
SUI_UNIT="${SUI_UNIT:-s-ui}"

cat > /usr/local/sbin/sb-selfheal.sh <<'EOF'
#!/bin/sh
STATE=/tmp/sb-selfheal-count
if ! pgrep -x sing-box >/dev/null 2>&1 || ! nc -z 127.0.0.1 443 2>/dev/null; then
    n=$(cat "$STATE" 2>/dev/null || echo 0); n=$((n+1)); echo "$n" > "$STATE"
    if [ "$n" -le 3 ]; then
        logger -t sb-selfheal "core down (check $n) — restarting $SUI_UNIT"
        systemctl restart "$SUI_UNIT"
    else
        logger -t sb-selfheal "crash-loop cap reached — manual attention needed"
    fi
else
    echo 0 > "$STATE"
fi
EOF
chmod +x /usr/local/sbin/sb-selfheal.sh

cat > /etc/systemd/system/sb-selfheal.service <<'EOF'
[Unit]
Description=sing-box local self-heal check
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/sb-selfheal.sh
EOF
cat > /etc/systemd/system/sb-selfheal.timer <<'EOF'
[Unit]
Description=Check sing-box every minute
[Timer]
OnBootSec=60s
OnUnitActiveSec=60s
AccuracySec=10s
Unit=sb-selfheal.service
[Install]
WantedBy=timers.target
EOF
systemctl daemon-reload
systemctl enable --now sb-selfheal.timer
echo "installed. verify: systemctl list-timers sb-selfheal.timer"
