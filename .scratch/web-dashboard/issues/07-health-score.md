# 07 — Network Health Score + /health endpoint

**What to build:** The derived Network Health Score exactly per ADR-0005: 100 − penalties (link 30, proxy 20, services 20, freshness 15, DNS 15), bands Excellent ≥90 / Good ≥75 / Degraded ≥50 / Poor <50. Pure compute (`hn_health_score`, `hn_health_band`); `/health` returns score + band + per-component breakdown with the raw detail each card renders.

**Blocked by:** 05, 06

**Status:** ready-for-agent

- [ ] `hn_health_score`/`hn_health_band` are pure and fixture-tested.
- [ ] `/health` returns `score`, `band`, `as_of_unix`, and one component object per weight (name/weight/penalty/detail).
- [ ] `test_health.sh` + `test_health_api.sh` green.
