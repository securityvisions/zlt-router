#!/bin/sh
# Full test suite: runs every test_*.sh with the shared harness.
# Exit 1 if any test file fails. Usage: sh tests/run.sh
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
failed=0
for t in "$HERE"/test_*.sh; do
    echo "== $(basename "$t") =="
    if sh "$t"; then :; else failed=1; echo ">>> $(basename "$t") FAILED"; fi
done
echo "=== suite exit: $([ "$failed" -eq 0 ] && echo OK || echo FAILED) ==="
exit "$failed"