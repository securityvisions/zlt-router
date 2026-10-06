#!/bin/sh
echo "=== VPS 1 (85.121.124.158) STATUS ==="
ssh -F /dev/null -i ~/.ssh/id_ed25519_agent -o StrictHostKeyChecking=no root@85.121.124.158 '
    uptime
    systemctl is-active sui || systemctl is-active s-ui
    journalctl -u sui -u s-ui --no-pager -n 20 2>/dev/null || true
' || echo "VPS 1 SSH failed"

echo ""
echo "=== VPS 2 (5.175.234.113) STATUS ==="
ssh -F /dev/null -i ~/.ssh/id_ed25519_agent -o StrictHostKeyChecking=no root@5.175.234.113 '
    uptime
    systemctl is-active sui || systemctl is-active s-ui
    journalctl -u sui -u s-ui --no-pager -n 20 2>/dev/null || true
' || echo "VPS 2 SSH failed"
