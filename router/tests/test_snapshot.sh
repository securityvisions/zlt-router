#!/bin/sh
# Fixture tests: snapshot builder contract (x28-snapshot.sh).
# The manifest/verify modes are the completeness proof behind every rollback
# snapshot: manifest emits sorted "sha256  ./path" lines over any local tree,
# verify recomputes and fails loudly on tampered, missing, or unexpected files.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
SNAP="$HERE/../x28/x28-snapshot.sh"

PASS=0; FAIL=0
assert_eq() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1"; printf '  expect: [%s]\n' "$2"; printf '  actual: [%s]\n' "$3"; fi; }
summary(){ echo "PASS=$PASS FAIL=$FAIL"; [ "$FAIL" -eq 0 ]; }
TMP=$(mktemp -d); trap 'rm -rf "$TMP"' EXIT

mkdir -p "$TMP/tree/a" "$TMP/tree/b/c" "$TMP/tree/empty"
printf 'hello' > "$TMP/tree/a/hello.txt"
printf '#!/bin/sh\necho hi\n' > "$TMP/tree/b/c/tool.sh"
printf 'x' > "$TMP/tree/a/x.bin"

# independent truth: well-known SHA-256 literals for the fixed contents
HELLO_SHA="2cf24dba5fb0a30e26e83b2ac5b9e29e1b161e5c1fa7425e73043362938b9824"

# ── 1. manifest: sorted lines, correct hashes, MANIFEST itself excluded ──────
out=$(sh "$SNAP" manifest "$TMP/tree")
line_count=$(printf '%s\n' "$out" | grep -c .)
assert_eq "manifest: three files listed" "3" "$line_count"
first=$(printf '%s\n' "$out" | head -1)
assert_eq "manifest: sorted order" "./a/hello.txt" "$(printf '%s' "$first" | awk '{print $2}')"
assert_eq "manifest: known-content hash" "$HELLO_SHA" "$(printf '%s\n' "$out" | awk '$2=="./a/hello.txt"{print $1}')"
printf '%s\n' "$out" > "$TMP/tree/MANIFEST.sha256"
out2=$(sh "$SNAP" manifest "$TMP/tree" | grep -c MANIFEST)
assert_eq "manifest: never lists itself" "0" "$out2"

# ── 2. verify: pristine tree passes ──────────────────────────────────────────
sh "$SNAP" verify "$TMP/tree" >/dev/null 2>&1
assert_eq "verify: clean tree exits 0" "0" "$?"

# ── 3. verify: tampered content fails loudly ─────────────────────────────────
printf '!' >> "$TMP/tree/a/hello.txt"
sh "$SNAP" verify "$TMP/tree" >/dev/null 2>&1
assert_eq "verify: tamper exits nonzero" "1" "$?"
# restore the fixture byte so later cases start clean
printf 'hello' > "$TMP/tree/a/hello.txt"
printf '%s\n' "$out" > "$TMP/tree/MANIFEST.sha256"

# ── 4. verify: missing file fails ────────────────────────────────────────────
mv "$TMP/tree/b/c/tool.sh" "$TMP/tree/tool.sh.bak"
sh "$SNAP" verify "$TMP/tree" >/dev/null 2>&1
assert_eq "verify: missing file exits nonzero" "1" "$?"
mv "$TMP/tree/tool.sh.bak" "$TMP/tree/b/c/tool.sh"

# ── 5. verify: unexpected extra file fails (completeness, both directions) ──
printf 'stray' > "$TMP/tree/extra.txt"
sh "$SNAP" verify "$TMP/tree" >/dev/null 2>&1
assert_eq "verify: extra file exits nonzero" "1" "$?"

summary
