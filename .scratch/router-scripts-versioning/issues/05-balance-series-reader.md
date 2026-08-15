# 05 — One balance-series reader (bot 14 points, API 90)
**What to build:** The balance history is read two incompatible ways today: the bot's sparkline
does `cat /etc/balance-log/*.log | cut -d'|' -f2 | tail -14` (botcmd.sh:108, 234) and the API's
history endpoint re-reads the same files as `date|gb` rows sorted newest-first
(ra_balance_series, routerapi_lib.sh:127-131). Add one `hn_balance_series [days] [format]`
reader to hnlib and switch both callers to it — the bot passes 14 (sparkline shape), the API
passes 90 (point shape). One reader, two thin adapters; the log format knowledge lives in one
place.
**Blocked by:** 01 — both callers are versioned before their readers merge
**Status:** ready-for-agent
