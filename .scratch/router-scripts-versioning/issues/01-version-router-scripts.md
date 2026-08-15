# 01 — Version the router-only scripts into the repo
**What to build:** Every script that runs on the router has a canonical copy in `router/`. Pull
the seven router-only modules into the repo as authoritative copies: `usage.sh` (182 lines, the
per-device usage CLI), `friday.sh`, `hyst.sh`, `monthly.sh`, `passwall-failopen.sh`,
`passwall-autorecover.sh`, `passwall-bypass-ensure.sh`. Re-sync the three drifted copies
(`balance.sh`, `routerapi.sh`, `routerapi_lib.sh`) so repo md5 == router md5 for all 17 scripts.
Record the deployment map (which repo file deploys to which router path) in
`docs/OPERATIONS.md`, and verify the suite still passes after the sync.
**Blocked by:** None — can start immediately
**Status:** ready-for-agent
