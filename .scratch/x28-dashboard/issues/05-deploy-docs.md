# 05 — Deploy + docs + live smoke

**What to build:** Push all components to the router (snapshot before first deploy), verify every endpoint from a real browser, update CONTEXT.md glossary (Dashboard, Snapshot layer, Action endpoint), AS_BUILT addendum, OPERATIONS quick-reference, and live-smoke every action from a real browser session.

**Blocked by:** 01, 02, 03, 04.

**Status:** ready-for-agent

- [ ] Rollback snapshot taken before first deploy
- [ ] Health gate GREEN before and after each deploy step
- [ ] Every GET endpoint returns valid JSON from a real browser
- [ ] Every POST action tested once from a real browser (assign, toggle, reboot-skip)
- [ ] CONTEXT/AS_BUILT/OPERATIONS updated in house style
- [ ] Full suite + typecheck green; all commits pushed
