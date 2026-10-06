#!/bin/sh
# Unit tests: router/device-registry.sh — deep device resolution and naming module.
HERE=$(cd "$(dirname "$0")" 2>/dev/null && pwd)
. "$HERE/lib.sh"

TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

cat > "$TMP/leases" <<EOF
1690 aa:bb:cc:dd:ee:ff 192.168.1.5 iPhone *
1690 96:04:e1:00:00:00 192.168.1.6 laptop *
1690 00:11:22:33:44:55 192.168.1.7 * *
EOF

echo "aa:bb:cc:dd:ee:ff MyPhone" > "$TMP/names"
echo "aa:bb:cc:dd:ee:ff" > "$TMP/watchlist"
echo "00:11:22:33:44:55 CachedCamera" > "$TMP/cache"

export DEV_REG_DHCP_LEASES="$TMP/leases"
export DEV_REG_USER_NAMES="$TMP/names"
export DEV_REG_WATCHLIST="$TMP/watchlist"
export DEV_REG_NAMES_CACHE="$TMP/cache"

. "$HERE/../device-registry.sh"

# Test 1: dev_reg_name respects priority: user > lease > cache > fallback
name_user=$(dev_reg_name "aa:bb:cc:dd:ee:ff")
assert_eq "dev_reg_name: user override wins" "MyPhone" "$name_user"

name_lease=$(dev_reg_name "96:04:e1:00:00:00")
assert_eq "dev_reg_name: DHCP lease fallback" "laptop" "$name_lease"

name_cache=$(dev_reg_name "00:11:22:33:44:55")
assert_eq "dev_reg_name: names cache fallback" "CachedCamera" "$name_cache"

name_unknown=$(dev_reg_name "de:ad:be:ef:00:01")
assert_eq "dev_reg_name: unknown fallback" "Unknown-de:ad:be" "$name_unknown"

# Test 2: dev_reg_get returns full canonical record
rec=$(dev_reg_get "aa:bb:cc:dd:ee:ff")
# Format: mac|name|source|ip|hostname|watched
assert_eq "dev_reg_get format" "aa:bb:cc:dd:ee:ff|MyPhone|user-names|192.168.1.5|iPhone|1" "$rec"

# Test 3: dev_reg_rename updates user-names atomically
dev_reg_rename "96:04:e1:00:00:00" "WorkLaptop"
assert_eq "renamed device reflects in dev_reg_name" "WorkLaptop" "$(dev_reg_name 96:04:e1:00:00:00)"
assert_eq "renamed file contains entry" "WorkLaptop" "$(awk '$1=="96:04:e1:00:00:00"{print $2}' "$TMP/names")"

# Test 4: dev_reg_set_watch toggles watchlist
dev_reg_set_watch "96:04:e1:00:00:00" 1
assert_eq "is watched after toggle 1" "1" "$(awk '$1=="96:04:e1:00:00:00"{print 1}' "$TMP/watchlist")"
dev_reg_set_watch "96:04:e1:00:00:00" 0
assert_eq "is unwatched after toggle 0" "" "$(awk '$1=="96:04:e1:00:00:00"{print 1}' "$TMP/watchlist")"

# Test 5: Device Trust Level resolution
export DEV_REG_ALLOW="$TMP/allow"
export DEV_REG_EXEMPT="$TMP/exempt"
export DEV_REG_BLOCKED="$TMP/blocked"
export DEV_REG_FLAG="$TMP/flag"
export DEV_REG_TRUSTED="$TMP/trusted"

# aa:bb:cc:dd:ee:ff has user name in $TMP/names => Known
assert_eq "trust level: named device is Known" "Known" "$(dev_reg_trust_level aa:bb:cc:dd:ee:ff)"

# unknown MAC without rules => Unknown
assert_eq "trust level: unknown MAC is Unknown" "Unknown" "$(dev_reg_trust_level 11:22:33:44:55:66)"

# Explicitly blocked => Blocked
dev_reg_set_trust "11:22:33:44:55:66" "Blocked"
assert_eq "trust level: blocked MAC is Blocked" "Blocked" "$(dev_reg_trust_level 11:22:33:44:55:66)"

# Explicitly trusted => Trusted
dev_reg_set_trust "11:22:33:44:55:66" "Trusted"
assert_eq "trust level: trusted MAC is Trusted" "Trusted" "$(dev_reg_trust_level 11:22:33:44:55:66)"

summary
