# 07 - Decouple Bot Command Execution from Telegram UI (bot-dispatcher)

Status: resolved
Type: task

## Question

How should `x28-bot.sh` and `botcmd.sh` decouple pure command rendering (`bot_render_card <cmd> [args]`) from Telegram delivery mechanisms, eliminating output divergence between inline keyboard taps and slash commands?

## Answer

1. **Unified Command Rendering Seam:** Implemented `bot_render_card <cmd> [arg]` in `router/x28/x28-bot.sh`:
   - Pure rendering interface covering: `status`, `link`, `usage`, `bill`, `balance`, `devices`, `proxy`, `budget`, `outages`, `digest`, `people`/`month`, and `help`.
   - Returns standard HTML card strings to stdout, completely decoupling execution/formatting from network delivery.
2. **Divergence Eliminated:**
   - Inline keyboard taps (`case "$action"`) delegate directly to `card=$(bot_render_card "$action")` and pass `$card` to `edit_panel`.
   - Text slash commands (`case "$cmd"`) delegate directly to `card=$(bot_render_card "$card_cmd" "$card_arg")` and pass `$card` to `html_send`.
   - Output divergence between `/status` (missing verdict on tap) and `/balance` (`head -12` vs `head -20`) is completely eliminated.
3. **Verification:**
   - Syntax validated: `sh -n router/x28/x28-bot.sh`.
   - Bot unit tests pass: `test_bot_panel.sh` (11/11), `test_bot_format.sh` (19/19), `test_bot_reliability.sh` (22/22, 12/12, 14/14).
   - Full repository test suite passes with `=== suite exit: OK ===`.
