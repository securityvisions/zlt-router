#!/bin/sh
# Unit tests: router/netpull.sh — device-canonical backup tool (ADR-0007).
# All device access goes through NETPULL_AX/NETPULL_X28 stubs — no real devices.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
N="$HERE/../netpull.sh"
T=$(mktemp -d)
trap 'rm -rf "$T"' EXIT

PASS=0; FAIL=0
ck() { if [ "$2" = "$3" ]; then PASS=$((PASS+1)); else FAIL=$((FAIL+1)); echo "FAIL - $1: expect [$2] actual [$3]"; fi; }

# --- fixtures -------------------------------------------------------------
# fake ssh "server" per host: AX holds /etc/axproxy.nft with content A;
# X28 holds dns-fix (content B) and probe-service (content C).
mkdir -p "$T/dev"
printf 'AXCONTENT\n' > "$T/dev/axfile"
printf 'X28FIX\n'    > "$T/dev/x28file"
printf 'X28PROBE\n'  > "$T/dev/x28probe"

# stub: last arg of the ssh command line is the remote command
make_stub() { # make_stub <name> — answers md5sum AND cat for the fixture paths
    cat > "$T/$1" << 'STUB'
#!/bin/sh
content_for() {
    case "$1" in
      *axproxy.nft*)            printf '%s' "AXCONTENT" ;;
      *dns-fix.sh*)             printf '%s' "X28FIX" ;;
      *probe-service*)          printf '%s' "X28PROBE" ;;
      *proxy-watchdog.sh*)      printf '%s' "WATCHDOGCANONICAL" ;;
      *) return 1 ;;
    esac
}
cmd="$1"; shift
case "$cmd" in
  cat)
    content_for "$1"
    exit 0 ;;
esac
# md5sum paths: either as args (plain md5sum) or on stdin (remote `xargs md5sum`)
if [ "$cmd" = "xargs" ]; then shift; fi
paths=""
[ "$cmd" = "xargs" ] && paths=$(cat) || paths="$*"
for p in $paths; do
  c=$(content_for "$p") || continue
  h=$(printf '%s' "$c" | md5sum | cut -d' ' -f1)
  printf '%s  %s\n' "$h" "$p"
done
STUB
    chmod +x "$T/$1"
}
make_stub stub_full

export NETPULL_ROOT="$T/repo"
export NETPULL_AX="$T/stub_full"
export NETPULL_X28="$T/stub_full"
mkdir -p "$NETPULL_ROOT"

# manifest is well-formed
n=$(sh "$N" manifest | grep -c '|')
[ "$n" -ge 10 ]; ck "manifest has >=10 entries" 0 $?

# status: repo empty -> everything NO-REPO
out=$(sh "$N" status)
echo "$out" | grep -q 'NO-REPO'; ck "status flags NO-REPO with empty repo" 0 $?

# pull all copies device files into the repo tree
out=$(sh "$N" pull all)
echo "$out" | grep -q 'pulled: proxy-watchdog'; ck "pull fetches proxy-watchdog (ticket 02)" 0 $?
[ -f "$NETPULL_ROOT/router/proxy-watchdog.sh" ]; ck "proxy-watchdog.sh exists in repo" 0 $?
grep -q 'AXCONTENT' "$NETPULL_ROOT/router/axproxy.nft" 2>/dev/null; ck "axproxy.nft content pulled" 0 $?

# status now matches for pulled files
out=$(sh "$N" status)
echo "$out" | grep 'dns-fix' | grep -q 'match'; ck "pulled entries report match" 0 $?

# simulate device-side drift: change the repo copy, status must flag DIVERGED
printf 'EDITED' >> "$NETPULL_ROOT/router/x28/dns-fix.sh"
out=$(sh "$N" status)
echo "$out" | grep 'dns-fix' | grep -q 'DIVERGED'; ck "status flags DIVERGED after repo-side edit" 0 $?
echo "$out" | grep 'probe-service' | grep -q 'match'; ck "untouched entries still report match" 0 $?

# pull single entry works
rm -f "$NETPULL_ROOT/router/proxy-watchdog.sh"
out=$(sh "$N" pull proxy-watchdog)
echo "$out" | grep -q 'pulled: proxy-watchdog'; ck "single-name pull works" 0 $?

# NEVER PUSHES: stub records every remote command; none may contain a write
cat > "$T/recorder" << 'EOF'
#!/bin/sh
echo "$*" >> "$RECORD"
case "$*" in
  *axproxy.nft*)  printf '%s' "AXCONTENT" ;;
  *dns-fix.sh*)   printf '%s' "X28FIX" ;;
  *probe-service*) printf '%s' "X28PROBE" ;;
  *) : ;;
esac
EOF
chmod +x "$T/recorder"
RECORD="$T/record.txt"
export RECORD
export NETPULL_AX="$T/recorder"; export NETPULL_X28="$T/recorder"
sh "$N" pull all > /dev/null 2>&1
if grep -qE '(>|>>|tee|mv|cp|chmod|chown|sed -i|rm ).*(/etc/|/data/|/usr/sbin/)' "$RECORD"; then
    FAIL=$((FAIL+1)); echo "FAIL - ADR-0007: netpull attempted a WRITE on a device"
else
    PASS=$((PASS+1))
fi

echo "PASS=$PASS FAIL=$FAIL"
[ "$FAIL" -eq 0 ]
