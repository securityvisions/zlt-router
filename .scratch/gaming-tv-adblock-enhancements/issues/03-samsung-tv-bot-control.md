# 03 - Samsung Q70C TV Power & Status Control via Telegram Bot

Status: resolved
Assignee: agent
Type: task
Blocked by: none

## Answer

1. **Root Cause / Opportunity:**
   - Samsung Q70C QLED TV (`192.168.1.105`) has open REST API port 8001 and Wake-on-LAN capability (MAC `c8:12:0b:32:7c:f2`).
   - The X28 cellular gateway hosts `@xirouterbot` (`x28-bot.sh`), but previously lacked L3 route to `192.168.1.0/24` and had no TV management integration.
2. **Resolution Applied:**
   - Established persistent bidirectional L3 static route on X28 (`192.168.1.0/24 via 192.168.70.2` in `/etc/config/network`), enabling direct IP reachability between X28 daemons and LAN devices.
   - Authored `/data/proxy/x28-tv.sh` (`router/x28/x28-tv.sh` in repo) with:
     - `tv_status`: queries REST API `http://192.168.1.105:8001/api/v2/` for live power, OS, and model data when active; falls back to ICMP ping and MAC discovery when standby/off.
     - `tv_wake`: invokes AX3000T's `/usr/bin/etherwake -b -i br-lan c8:12:0b:32:7c:f2` to send Layer 2 Wake-on-LAN magic packets across the physical LAN bridge.
   - Integrated into `x28-bot.sh`:
     - Added `panel:tv` button to `panel_keyboard`.
     - Added `tv` to `bot_render_card` pure rendering interface.
     - Added `/tv` and `/tv on|wake` command handlers.
   - Verified end-to-end: bot tests pass 100% and live queries return formatted TV telemetry.


## Question

How should `@xirouterbot` and `x28-bot.sh` interact with Samsung Q70C TV (`192.168.1.105`) via REST API port 8001 (or SDB 26101) to query live power/app state and expose a remote power toggle button?

### Specifications & Context

1. **Samsung REST API v2 (`http://192.168.1.105:8001/api/v2/`):**
   - Query info: `GET /api/v2/` returns JSON with device power status, network, OS version, and model name.
   - Power Toggle: WebSocket or Wake-on-LAN (WOL MAC `c8:12:0b:32:7c:f2`) for power on; REST/WebSocket key event `KEY_POWER` for toggle/off.
2. **Telegram Bot Interface:**
   - Add `/tv` command and inline button `📺 TV Control` in the main panel.
   - Display TV status (ON/OFF, current active app if available) with action buttons (`Power`, `Volume Mute`, `Open YouTube/TizenTube`).
