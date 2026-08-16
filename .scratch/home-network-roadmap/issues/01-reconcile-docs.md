# 01 — Reconcile the docs with the live system

**What to build:** The architecture and operations docs stop contradicting the live network, so anyone (human or agent) reading the repo believes what the routers actually do. ARCHITECTURE describes the failover chain as shipped, SQM is 55/10 everywhere, and the ops + monitoring docs list every live cron and its alert.

**Blocked by:** None — can start immediately.

**Status:** resolved (docs reconciled)

- [ ] ARCHITECTURE.md describes the failover chain (`cdn_ws → REALITY → hysteria2 → via_x28 → fail-open`) as live, matching the ticket statuses.
- [ ] OPERATIONS.md and MONITORING_ALERTS.md list every live cron (`x28watch` */5, `backup.sh` nightly, `speedtest.sh` nightly, `vpshealth.sh` */10) and its alert.
- [ ] SQM is stated as 55/10 Mbps everywhere; the 35/10 drift is gone.
