# 03 - ProbeService seam for BOTH devices (which callers migrate, where does it live)

Status: open
Type: grilling

## Question

ProbeService (router/x28/probe-service.sh) is the intended single health-check seam, but it lives on X28 only, and AX3000T's proxy-watchdog.sh has its own dual-endpoint probe. Decisions to walk:

1. Which of the 5 probe implementations migrate to ProbeService, and in what order (dns-fix inline fallback, x28-vps-heal auto-grep, operator-watchdog curl, AX3000T proxy-watchdog dual-endpoint)?
2. Does AX3000T get its own copy of probe-service.sh (deployed like other repo-authored tools), and do the two copies share one canonical repo file with per-device profile config?
3. What is the exit-code contract every caller must honor (tonight's bug: `echo dead` returned 0)?
4. Which env seams make it testable fixture-first in router/tests/ (pattern: test_dns.sh)?

## Evidence

- Sept 16: probe-service.sh had dead port 1070 AND returned exit 0 when dead (both fixed live, now in repo).
- 5 independent curl-probe implementations counted in the Sept 16 architecture review.
