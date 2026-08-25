# 08 — Health gate watches the dashboard

**What to build:** The 2026-08-25 outage (crash-looped web server, no listener on :8080 for ~a day) was invisible to every alarm because the health gate has no dashboard check. Add dashboard availability to the one-command health verdict: the procd instance reports running AND a local HTTP fetch of the dashboard root and one API snapshot endpoint returns 200. Because the Boot doctor's post-boot gate, the watchdog loops, and the digests all already consume this same verdict, this single check buys boot-time detection and Telegram surfacing automatically — no new alerting plumbing.

End-to-end outcome: stopping the dashboard service turns the next health run RED within one cycle and surfaces wherever health already reports (boot card, watchdog notifications); starting it again flips GREEN.

**Blocked by:** None — can start immediately.

**Status:** resolved

- [x] Health gate fails (RED) when the dashboard service is down or :8080 stops answering locally
- [x] Check covers both static page and one API snapshot endpoint
- [x] Boot doctor boot card reflects a dashboard failure without extra wiring
- [x] Check is fast (≤4 s worst case: two `-m 2` probes; instant when the port refuses) and read-only; GREEN path adds no meaningful latency to the gate

## Answer

Health gate gained dash_page/dash_api checks (-m 2 curls against DASH_BASE_URL, default http://192.168.70.1:8080) behind an X28_HEALTH_GROUPS filter that defaults to all groups — production behavior otherwise unchanged, so the Boot doctor and every health reader pick this up with no wiring. On-device slice run: PASS/PASS, GREEN, rc=0. Contract tested by tests/test_dashboard_health.sh (13 assertions incl. dead-port and API-missing RED paths).

Deviation from the original wording: the "procd reports running AND HTTP 200" conjunction shipped as HTTP-only by design — HTTP failure catches every user-visible symptom (crash-loop, stopped service, port held by a wrong process), while parsing procd/ubus output would add a brittle dependency for no extra signal. The latency box was re-worded to the honest ≤4 s worst case for two probes.
