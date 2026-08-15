#!/bin/sh
# Unit tests: router/backup.sh — snapshot rotation.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
B="$HERE/../backup.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# Create 5 snapshots, keep 3 -> 2 removed, 3 remain.
for d in 2026-08-11 2026-08-12 2026-08-13 2026-08-14 2026-08-15; do
    : > "$TMP/backup-$d.tar.gz"
done
sh "$B" --rotate "$TMP" 3 >/dev/null
left=$(ls -1 "$TMP"/backup-*.tar.gz | wc -l)
[ "$left" = "3" ] && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - rotate keep 3: left=$left"; }
ls -1 "$TMP"/backup-*.tar.gz | grep -q "2026-08-15" && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - newest kept"; }
ls -1 "$TMP"/backup-*.tar.gz | grep -q "2026-08-11" && { FAIL=$((FAIL+1)); echo "FAIL - oldest not removed"; } || PASS=$((PASS+1))

# Empty dir is a no-op.
sh "$B" --rotate "$TMP/empty" 5 >/dev/null 2>&1 && PASS=$((PASS+1)) || { FAIL=$((FAIL+1)); echo "FAIL - empty rotate"; }

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
