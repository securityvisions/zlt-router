#!/bin/sh
# Unit tests: router/quarantine.sh — blocked-MAC decision (pure seam).
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
Q="$HERE/../quarantine.sh"

PASS=0; FAIL=0
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT
ck() {  # ck <desc> <expected> <actual>
    if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else
        FAIL=$((FAIL+1)); echo "FAIL - $1: expect [$2] actual [$3]"; fi
}

printf '1 aa:bb:cc:dd:ee:01 192.168.1.10 host1 *\n1 aa:bb:cc:dd:ee:02 192.168.1.11 host2 *\n1 aa:bb:cc:dd:ee:03 192.168.1.12 host3 *\n' > "$TMP/leases"
printf 'aa:bb:cc:dd:ee:02\n' > "$TMP/allow"
printf 'aa:bb:cc:dd:ee:03\n' > "$TMP/exempt"

out=$(QUARANTINE_ALLOW="$TMP/allow" QUARANTINE_EXEMPT="$TMP/exempt" sh "$Q" --blocked "$TMP/leases")
ck "blocks unapproved only" "aa:bb:cc:dd:ee:01" "$out"
out=$(QUARANTINE_ALLOW="$TMP/allow" QUARANTINE_EXEMPT="$TMP/exempt" sh "$Q" --blocked "$TMP/empty")
ck "empty leases -> none" "" "$out"
out=$(QUARANTINE_ALLOW="$TMP/allow" QUARANTINE_EXEMPT="$TMP/exempt" sh "$Q" --blocked "$TMP/nonexistent")
ck "missing leases -> none" "" "$out"

# approve persists to the allow file.
out=$(QUARANTINE_ALLOW="$TMP/allow" QUARANTINE_EXEMPT="$TMP/exempt" sh "$Q" --approve aa:bb:cc:dd:ee:01)
ck "approve reports" "approved aa:bb:cc:dd:ee:01" "$out"
out=$(QUARANTINE_ALLOW="$TMP/allow" QUARANTINE_EXEMPT="$TMP/exempt" sh "$Q" --blocked "$TMP/leases")
ck "after approve nothing blocked" "" "$out"

# revoke removes approval.
out=$(QUARANTINE_ALLOW="$TMP/allow" QUARANTINE_EXEMPT="$TMP/exempt" sh "$Q" --revoke aa:bb:cc:dd:ee:02)
ck "revoke reports" "revoked aa:bb:cc:dd:ee:02" "$out"
out=$(QUARANTINE_ALLOW="$TMP/allow" QUARANTINE_EXEMPT="$TMP/exempt" sh "$Q" --blocked "$TMP/leases")
ck "revoked device blocked again" "aa:bb:cc:dd:ee:02" "$out"

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
