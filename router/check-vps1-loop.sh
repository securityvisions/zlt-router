#!/bin/sh
echo "=== VPS 1 PORTS AND PROCESSES ==="
ssh -F /dev/null -i ~/.ssh/id_ed25519_agent -o StrictHostKeyChecking=no root@85.121.124.158 '
    echo "--- Top CPU processes ---"
    ps aux --sort=-%cpu | head -n 8

    echo ""
    echo "--- S-UI status & inbounds ---"
    systemctl status sui --no-pager -l | head -n 25

    echo ""
    echo "--- What is port 27328? ---"
    ss -tulpn | grep 27328 || echo "No 27328"
'
