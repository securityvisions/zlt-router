# 03 — Slim x28-bot.sh to pure dispatcher

**What to build:** After tg-lib and cards extraction, x28-bot.sh shrinks to ~150 lines: config load, instance lock, long-poll loop, update parsing, and a thin case statement that routes each command to its data source + card renderer + delivery call. Supervision loop stays here too. No formatting functions, no shell-out bodies, no keyboard builders.

**Blocked by:** 01, 02.

**Status:** ready-for-agent

- [ ] Bot file ≤200 lines; zero awk programs; zero inline HTML construction
- [ ] Command dispatch is one-line-per-command: route → render → deliver
- [ ] Full suite green; deployed live; /help · /status · /panel smoke-tested
