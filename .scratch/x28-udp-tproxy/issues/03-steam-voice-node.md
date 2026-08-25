# 03 — Steam voice node selection

**What to build:** Steam voice traffic is pinned to the best proxy node (from ticket 01's measurement, defaulting to the UDP-native node) via a rule-set over Valve's known CIDRs, inserted above the catch-all rule. A small script switches the pinned node in the engine config and hot-reloads it, reports the current pin, and validates the node exists. Voice quality is measured before/after.

**Blocked by:** ~~02~~ — delivered via the scoped-TUN design change instead.

**Status:** resolved

- [x] Engine config gains a Steam-voice rule-provider (Valve CIDRs) with a rule-set line pinned to a default node
- [x] Script switches the pinned node (validates it exists), hot-reloads the engine, reports current pin with no args
- [x] Fixture tests: node swap rewrites the rule line; current-node readout; invalid node rejected
- [x] Live: voice uses the pinned node; RTT/quality measured before and after
## Answer

Shipped: `steam-voice.yaml` provider over Valve CIDRs, `RULE-SET,steam-voice,hy2` live in the engine config, `steam-node.sh` pin/show/validate with hot reload, fixture-tested (test_steam_node.sh).
