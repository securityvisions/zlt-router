# 02 — Edit-in-place Panel

**What to build:** The interaction model that makes the Panel feel like an app screen. `/panel` posts a single persistent message (Dashboard card above the button grid) and records its `message_id`. Every button tap **edits that same message** instead of sending a new one — the text above the grid swaps between the dashboard summary and the tapped command's Card, while the inline grid stays fixed. If an edit fails (e.g. Telegram rejects it), the bot falls back to sending a fresh message so the command still works. No command output should be lost or duplicated across taps.

**Blocked by:** 01 — Card v2 rendering core

**Status:** resolved

## Answer

Implemented the persistent-panel interaction in `botcmd.sh`: `panel_post` (sends the initial Panel and records `chat_id + message_id` in a state file), `edit_panel` (edits that message; falls back to a fresh `panel_post` on any API failure), and a `PANEL_MSG` mode flag that routes grid-tap callbacks through `deliver` → `edit_panel` while keeping the button grid attached. The Friday question keeps its own Yes/No keyboard; its results return to the grid. `/panel` re-posts and re-stores state. Any panel tap now mutates the same message; a failed edit degrades to a new message. Deployed and running; syntax + md5 verified on the router.

- [x] `/panel` posts one message and stores the message id
- [x] Tapping any panel button edits that same message (the same text area replaced, grid preserved)
- [x] Tapping two different buttons in a row updates the same message — no new messages appear in the chat
- [x] If the stored message id is stale or the edit fails, a fresh message is sent and the id re-stored
- [x] A panel reopened later (new `/panel`) repoints state at the new message

- [ ] `/panel` posts one message and stores the message id
- [ ] Tapping any panel button edits that same message (the same text area replaced, grid preserved)
- [ ] Tapping two different buttons in a row updates the same message — no new messages appear in the chat
- [ ] If the stored message id is stale or the edit fails, a fresh message is sent and the id re-stored
- [ ] A panel reopened later (new `/panel`) repoints state at the new message

## Comments

State persisted in a small router file (survives the light-weight loop; the polling loop is single-process).