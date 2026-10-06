# 04 - Install and Configure Darkstat Per-Device Traffic Monitor

**Type:** `task`  
**Status:** resolved

## Resolution

1. Installed `darkstat` and `libpcap1` via `apk add darkstat` (total download size ~120 KiB).
2. Configured in `/etc/config/darkstat`:
   - Monitored interface: `br-lan`
   - Web server listening on `0.0.0.0:667`
   - Privilege separation: runs as `nobody` inside `/var/darkstat` chroot jail.
3. Enabled on boot (`/etc/init.d/darkstat enable`) and verified HTTP 200 response on `http://192.168.1.1:667/`. Real-time per-host bandwidth graphs are live.  
**Blocked by:** none  

## Question

How to install and configure the ultra-lightweight `darkstat` network monitor (<100 KiB flash footprint) to visualize per-device bandwidth usage via a web interface at `http://192.168.1.1:667`?

## Execution Plan

1. Install `darkstat` via `apk add darkstat`.
2. Configure `/etc/config/darkstat`:
   - Bind interface to `br-lan`.
   - Web interface listening on `192.168.1.1` port `667`.
   - Enable local host name resolution.
3. Enable and start `/etc/init.d/darkstat`.
4. Test HTTP response on `http://192.168.1.1:667`.
