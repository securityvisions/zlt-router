# 01 — URI→YAML converter (all 8 protocols) + hostile-input fixtures

**What to build:** Convert collected proxy URIs (vless incl. reality, vmess b64-JSON, trojan, shadowsocks all dialects, hysteria/hy2, tuic, juicity) into a mihomo `proxies:` YAML fragment, strictly: per-protocol allowlist grammars, hard caps (line ≤2048 chars, ≤300 candidates, host/port/uuid validation), silent per-candidate drop on any violation, stable unique names, dedupe by identity. Never touches owned config paths.

**Blocked by:** None — can start immediately.

**Status:** ready-for-agent

- [ ] Valid known-answer fixture per protocol converts to expected YAML fields
- [ ] Hostile corpus (oversized fields, bad base64, injection shapes, wrong schemes, >300 lines) drops offenders without aborting the whole run
- [ ] Deterministic naming + dedupe by type/host/port/credential-hash
- [ ] Runs identically on host (tests) and device (busybox base64/sha256sum/jq)
