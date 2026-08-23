# 02 — Extract card renderers into cards.sh

**What to build:** Every command's output rendering becomes a pure function in `cards.sh`: `render_status(status_text, health_line)`, `render_ledger_card(agg_rows, jmonth, label)`, `render_devices(leases_text)`, etc. Each takes explicit inputs (fixture-friendly), returns an HTML string. Zero shell-outs to live scripts — the dispatch layer calls child scripts, passes results to renderers. The bot dispatch arms shrink to: parse args → call script → call renderer → deliver.

**Blocked by:** 01 — needs the transport seam to know what "deliver" means.

**Status:** ready-for-agent

- [ ] One render_* function per user-facing card (status, link, usage, devices, balance, proxy, budget, outages, people/month, owner, rescue, wifi caption, digest, bill, help)
- [ ] All take explicit inputs; no shell-outs to child scripts inside cards.sh
- [ ] esc() applied to every dynamic value at the sink
- [ ] Golden-output tests per renderer using fixture inputs
- [ ] Bot dispatch arms shrink to: collect data → call renderer → deliver via tg-lib
