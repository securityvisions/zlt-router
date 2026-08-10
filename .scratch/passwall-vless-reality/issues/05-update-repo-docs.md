# 05 — Update repo docs for the new proxy default

**What to build:** The repo docs describe the router's proxy reality: VLESS+REALITY is the default node with hysteria2 as automatic failover, and the docs explain how to switch back to hysteria-only. The glossary entry for the active proxy protocol/node is corrected, and the operations/troubleshooting guidance mentions the new default and the revert path.

**Blocked by:** 04

**Status:** ready-for-agent

- [ ] CONTEXT.md's proxy glossary entry states the new default and failover setup
- [ ] OPERATIONS.md documents the new default node and how to revert to hysteria-only
- [ ] No stale references to hysteria being the single active node remain
