# 01 — Panel framework + beautiful Card seam

**What to build:** `Telegram bot` shows the 4×2 `Panel` (`📊 Status` `📶 Link` `💾 Usage` `💰 Balance` `📱 Devices` `🧾 Bill` `🛰️ Proxy` `❓ Help`) via inline keyboard; tapping edits the message in place (`editMessageText` + `answerCallbackQuery`). The `Card` anatomy (title/divider/`<pre>` with `botlib.sh:bar/spark/pad/temp_badge`) becomes the single seam every later card uses.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] `x28-bot.sh` handles `callback_query` (not only `message`), answers it, and edits the Panel message in place; the keyboard persists.
- [x] All cards render via `botlib.sh:card` + `esc` + `bar/spark` helpers; HTML `parse_mode` is set.
- [x] Fixture test: `Panel` JSON → correct `reply_markup` inline_keyboard structure.
