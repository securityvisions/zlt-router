# 03 — Pin the usage.sh CLI contract with tests
**What to build:** The six-flag CLI of `/root/usage.sh` (`--today --raw --month --names --name
--resolve`) is called from ten sites across botcmd.sh, billing.sh and routerapi_lib.sh, but its
behavior is enforced by nothing. Write fixture-based tests (the RA_USAGE_SH / path-override
trick from router/tests/lib.sh) that pin each flag's output shape: `--today` emits
`name|mac|bytes`, `--month [YYYY-MM]` the same for a month log, `--name <mac>` the resolved
name, `--resolve` a full mac from a prefix, `--names` the full device list. The tests document
the contract so any future change to usage.sh must keep the ten call sites working.
**Blocked by:** 01 — usage.sh must be versioned in the repo before its contract can be pinned
**Status:** ready-for-agent
