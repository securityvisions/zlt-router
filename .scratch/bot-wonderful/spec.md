# bot-wonderful — spec

Make the Telegram bot wonderful: from 8 text commands to a full Panel with live visuals — inline keyboard, beautiful Cards with bar/spark/temp_badge, Device Trust, Balance/Bill gauges, Proxy switch, and Alerts as Cards.

## Context

The X28 bot (`x28-bot.sh:132`) currently serves `/status /link /usage /bill /balance /switch_* /help` as plain text via `botlib.sh:card`. The AX3000T Panel (botcmd.sh) had a 4×2 grid with edit-in-place; ADRs and CONTEXT.md define Panel, Card, Dashboard card, Device Trust level, Alerts, and the Samantel Data plan/Package model.

## Tickets

1. Panel framework + beautiful Card seam
2. Wonderful Status/Link/Dashboard card
3. Device Trust + Devices card
4. Balance + Bill with gauges
5. Proxy & Alerts as Cards

Edges: 01 -> {02,03,04} -> 05 (05 needs 02 for Link context).
