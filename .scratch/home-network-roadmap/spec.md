# Home Network — Next Phases

The next phases for the home-network system, settled by grilling session
(2026-08-16). All five directions are in scope; this spec fixes the sequence,
the per-phase scope, and the shipping rules. The governing constraint (ADR
0003): two devices, no new hardware, VPS tier as the only upgrade lever.

## Context

The system today (all live): failover chain with fail-open (`cdn_ws → REALITY →
hysteria2 → via_x28 → direct`), link stickiness watchdog (`x28watch.sh`), X28
crypto engine (`x28proxy`), link card (Router API `/link` + bot `/link`), nightly
backups, daily speedtest, VPS health probes, SQM 55/10, the Telegram bot + Router
API + Xirouter app, Samantel balance (read-only — auto-payment is abandoned).

Open items inherited from `x28-smart-edge`: #06 app link card (pending), #08
Cloudflare tunnel (blocked on user credentials), #11 tproxy guest/backup net and
#12 Stage-2 split-proxy edge (written, opt-in, not enabled).

## Settled decisions

- **Probing is hybrid and bandwidth-frugal:** cheap `generate_204` latency probes
  on the chain's short cadence, passive throughput derived from the hourly
  telemetry `total_gb` deltas, and a targeted throughput sample only on
  suspicion of degradation. The daily speedtest stays the one hard number.
- **Escalation ladder is node → operator → fail-open**, in that order, escalating
  only when the cheaper rung did not fix it. `passwall-failopen.sh` and
  `x28watch.sh` stay separate seams; the quality layer coordinates them.
- **Failback is automatic with hysteresis:** return to the preferred node after
  2 consecutive healthy checks, to avoid flapping between near-equal nodes.
- **Quality state lives on the AX3000T:** a live file the chain reads plus an
  hourly append to the telemetry log (forensics).
- **Alerts follow the existing pattern:** cooldown-gated `tg.sh`; thresholds
  env-tunable, defaulting to the speedtest's 10 Mbps floor.
- **Security-model changes (B's guest/quarantine, E's #11/#12) ship behind
  opt-in gates**, never force-enabled live.

## Phases

### Phase 0 — reconcile (no build risk, free)
- ARCHITECTURE.md: failover chain is *live*, not "planned"; SQM is 55/10.
- OPERATIONS.md + MONITORING_ALERTS.md: add the missing crons
  (`x28watch` */5, `backup.sh` daily, `speedtest.sh` daily, `vpshealth.sh` */10)
  and their alerts; fix the SQM number drift (35/10 vs 55/10).
- Glossary already carries **Fail-open**, **Degraded link**, **Link quality**
  (CONTEXT.md, "Resilience").

### Phase A — quality & self-healing (first build)
- Hybrid quality measurement (see Settled decisions).
- Quality-aware node selection: rank the chain by measured quality, not just
  probe-aliveness.
- Escalation ladder node → operator → fail-open (see Settled decisions).
- Auto-failback with 2-check hysteresis.
- Hourly link-quality forensics appended to telemetry; degraded-mode alerts.
- The #06 app link card rides along (it consumes `/link`).

### Phase B — remote & security (parallel; credential-gated)
- Activate the Cloudflare tunnel (`cloudflared-setup.sh`) — blocked on the
  user's Cloudflare credentials, never blocks the build.
- Guest-network isolation, ad-block DNS hardening, device quarantine.
- Opt-in gates for every security-model change.

### Phase E — two-box extraction (after A)
- Enable #11: X28 guest/backup network gets proxied internet via tproxy even if
  the AX3000T is offline.
- Enable #12: Stage-2 — X28 as primary proxy edge with domestic-direct /
  international-proxied split. After A, so the split routes on real quality data.
  Side effect: domestic-direct cuts VPS bandwidth spend.

### Phase C — cost discipline (on A's forensics + the billing stack)
- Honest forecasts, per-person quotas with crossing events, Friday-discount
  offload automation, pre-bill budget alerts.

### Phase D — family UX (last; consumes everything)
- App spec-v2 **core first**: per-person usage roll-up, payments ledger + person
  credit, monthly quotas, honest forecasts. Then the productivity layer: inbox,
  automation rules, saved views / command palette, backup-restore, device
  enrichment.
- Core ships alone; the productivity layer follows.

## Shipping rules

- Each phase ships independently, tested at the seams (`router/tests/run.sh`),
  deployed via the existing push/deploy paths.
- A deploys incrementally — the failover chain keeps fail-open as its terminal
  rung, so a half-deployed quality layer cannot take the network down.
- B, E, C, D follow ship-as-completed, with opt-in gates wherever the security
  model changes.

## Tracking

Tickets will be cut per phase when the phase starts (repo pattern:
`.scratch/<project>/issues/NN-slug.md`). Phase 0 + A are the first `matt-implement`
target.
