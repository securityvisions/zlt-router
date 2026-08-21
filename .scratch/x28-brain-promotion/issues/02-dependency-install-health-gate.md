# 02 — Dependency install + x28-health gate

**What to build:** Two things that make every later deploy safe. First, a
`x28-health` gate script that answers one question in one command — "is
the X28 still fully working?" — checking the DNS chain (dnsmasq resolves,
upstream tunnel forwarder alive), the proxied path (a fetch through the
VPS egress returns 200), the direct path (the exempted host returns 200
direct), the presence of the transparent-proxy and QUIC-block iptables
chains, and the liveness of the proxy core + operator watchdog. Second,
the one dependency the ported brain scripts need (`jq`), installed with
the gate run green **before and after**.

**Blocked by:** 01 — Rollback snapshot + restore drill.

**Status:** resolved (gate at `/data/proxy/x28-health.sh`, 3× GREEN; jq 1.7.1
static at `/data/proxy/jq` — the vendor feed has no jq, so a static binary
replaced opkg, touching nothing system-level; sha256-verified transfer)

- [x] `x28-health` prints one line per check with pass/fail and exits
      nonzero on any failure; green on the current live box.
- [x] `jq` installed and working on the X28; the vendor dnsmasq binary
      and config generation are untouched (no dnsmasq-full, no web-panel
      packages).
- [x] Gate output captured before and after the install, both green.
- [x] Canonical copy of the gate script lands in the repo with deploy
      wiring, ready for every later ticket to reuse.
