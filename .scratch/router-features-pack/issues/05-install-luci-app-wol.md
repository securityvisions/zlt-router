# 05 - Install LuCI Wake-on-LAN Button (luci-app-wol)

**Type:** `task`  
**Status:** resolved

## Resolution

1. Verified that `luci-app-wol` is already installed and fully integrated into LuCI under **Services -> Wake on LAN** (`/cgi-bin/luci/admin/services/wol`).
2. Verified underlying binary `/usr/bin/etherwake` on `br-lan`.
3. The LuCI interface automatically populates configured hosts from `/etc/config/dhcp` (`WIN10-PC` with MAC `10:02:b5:ac:c1:e1` and `parsavisions-lan` with MAC `a8:2b:dd:8c:cf:fc`), allowing instant one-click Wake-on-LAN without typing MAC addresses. Zero extra bytes installed.  
**Blocked by:** none  

## Question

How to add a web button to the LuCI interface (`luci-app-wol`, ~8 KiB) to wake sleep/powered-off PCs on the LAN using the pre-installed `etherwake` binary?

## Execution Plan

1. Install `luci-app-wol` via `apk add luci-app-wol`.
2. Verify package installation under `/www/luci-static/resources/view/status/wol.js` or LuCI Services menu.
3. Reload rpcd and uhttpd.
4. Verify web endpoint accessible in LuCI.
