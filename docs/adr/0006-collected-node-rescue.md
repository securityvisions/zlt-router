# ADR-0006: Collected-node rescue pool

Date: 2026-08-23 · Status: accepted · Deciders: parsa + agent

## Context

The household's censorship-bypass path ultimately depends on one VPS. Tickets 01–06 of x28-always-up shortened every *recovery*, but if that server dies outright, filtered internet stays down until it returns. Public Telegram channels continuously publish proxy configs that could serve as emergency exits.

## Decision

1. **Trust boundary (owner decision):** during total owned-node failure, ALL traffic may ride collected third-party exits ("full failover"). Privacy exposure during outages is explicitly accepted; reversible anytime via `/rescue off`.
2. **Containment:** scraper output never touches owned config paths. Collected candidates live in a separate file-backed provider; a malformed/unhealthy pool degrades to an empty rescue group only.
3. **Admission by engine-native handshakes:** the collector's TCP-open check is treated as a hint only; admission requires the engine's own delay test.
4. **Cold-start resolution:** collect while healthy (6 h cadence), consume the on-disk cache during outages.
5. **Activation semantics:** separate `rescue` group behind a `world` selector; promote after ~4 min owned-dead, demote after ~10 min stable; persisted kill switch.

## Consequences

- Single-server ceiling removed as a hard dependency (pool refreshes automatically).
- Outage-time privacy is reduced to "whatever the channel posters see" — documented, accepted.
- Parser surface vs untrusted input exists but is bounded (allowlists, caps, per-candidate drop).
- Upstream Go binary replaced by an auditable ~100-line sh scraper (same output contract).
