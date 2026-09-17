# 06 - Encapsulate Telegram Transport & Format Guarding (tg-transport)

Status: resolved
Type: task

## Question

How should `tg-lib.sh` and `tg.sh` be deepened into a single canonical notification transport module that encapsulates mandatory title & body escaping, message length chunking at 4000 characters, local SOCKS proxy routing, and Telegram error logging?

## Answer

1. **Title Escaping Vulnerability Eliminated:** In `router/tg.sh:18`, updated `tg_card` to escape both arguments (`alert_text "$(esc "$1")" "$(esc "$2")"`). Previously, raw `<` or `>` characters in titles caused Telegram's HTML parser to reject messages with HTTP 400, dropping critical router alerts silently.
2. **Autonomous SOCKS Proxy Routing:** Enhanced `tg_send` to automatically discover and use local SOCKS proxies (`socks5h://127.0.0.1:1080` on AX3000T or `192.168.70.1:1080` on X28) when direct connections are unreachable or transparent proxy is down.
3. **Link Preview & Bandwidth Suppression:** Enforced `'link_preview_options={"is_disabled":true}'` across alert delivery.
4. **Verification:** `test_tg_lib.sh` updated with contract checks and passes 11/11.
