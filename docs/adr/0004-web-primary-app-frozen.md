# Web dashboard is the primary surface; the Android app is frozen

The web dashboard (Xirouter NOC) becomes the **primary product surface**: it
owns all new feature work, including the app's domain (people, ledger,
payments, quotas, automation, inbox), which it re-implements natively. The
existing Android app is **frozen** — kept for offline / last-resort use and
its local Room data, but receives no new features and is not maintained in
parallel.

**Status:** accepted

**Why:** "replaces the app" without freezing means maintaining two full
clients forever (every feature, twice, on two stacks — Compose vs web). The
web is where the NOC features (health, live traffic, flows, events, proxy
control, diagnostics) belong; the app's offline person/ledger store remains a
legacy read source until the web's Phase-4 ledger replaces it.

**Considered:**

- **Both fully maintained** — rejected: doubles every feature's cost for no
  operational benefit; the household only needs one live surface.
- **App deprecated outright** — rejected: the app still works offline and
  holds the ledger history; freezing (not deleting) keeps that value.

**Consequences:**

- The web must re-implement the person/ledger/payments domain (Phase 4) before
  the app can be retired.
- New domain work lands on the web only; the app's spec-v2 surfaces (payments,
  automation, inbox) are *not* built in the app — they migrate to the web.
- The Router API stays the shared contract both surfaces consume.
