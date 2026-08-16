# 14 — Friday-discount offload automation

**What to build:** Heavy scheduled work — backups, large downloads — shifts into the Friday discount window (4,620 T/GB instead of 7,700), and the window opening is announced through the existing alert path.

**Blocked by:** None — can start immediately.

**Status:** resolved (friday-offload.sh queue + announce + tests; cron 09:00)

- [ ] Scheduled heavy jobs land inside the Friday discount window.
- [ ] Window opening is announced via the existing alert path.
- [ ] Verifiable live (a Friday run proves the timing).
