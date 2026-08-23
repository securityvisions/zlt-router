# 01 — Extract Telegram transport into tg-lib.sh

**What to build:** All Telegram API knowledge (HTTP transport, parse_mode, chunk budget, preview suppression, response-aware logging, error taxonomy) moves from the bot into a dedicated `tg-lib.sh` module with a narrow interface: `send(html)`, `edit(mid, html)`, `send_photo(path, caption)`, `ack_cbq(id)`. The bot sources it and calls these four functions — zero curl/parse_mode/4096 logic remains in the dispatcher. The module is testable standalone (source + stub curl).

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] tg-lib.sh exports: send, edit, send_photo, ack_cbq, post (generic)
- [ ] Chunk budget (MAXMSG), preview suppression, HTML parse_mode are module constants/config
- [ ] Response-aware logging (error_code/description → caller-supplied log fn) built in
- [ ] Zero knowledge of commands, cards, or router state
- [ ] Existing test_bot_format.sh and test_bot_reliability.sh pass unchanged (backwards compat via re-export)
- [ ] New test_tg_lib.sh tests chunk boundaries and error taxonomy in isolation
