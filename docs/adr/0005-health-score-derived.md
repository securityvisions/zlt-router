# Network Health Score is derived, never a sensor

The dashboard's **Network Health Score** (0–100) is a *computed* composite of
existing measurements — link quality (30), proxy state (20), service health
(20), telemetry freshness (15), DNS health (15) — not a measurement the routers
produce. The formula and bands (Excellent ≥ 90, Good ≥ 75, Degraded ≥ 50,
Poor < 50) live in one pure function.

**Status:** accepted

**Why:** the score must be explainable — "score 70: link degraded" — and the
underlying signals already exist (quality module, proxy probe, service probe,
telemetry, dnsmasq stats). Adding a dedicated sensor would be a parallel system
that nothing else reads, and a future reader might "fix" the number by adding
one.

**Consequences:**

- The score is never a device read; it recomputes from the same data the rest
  of the dashboard shows.
- A new measurement that matters (e.g., jitter) becomes a component weight,
  not a second score.
