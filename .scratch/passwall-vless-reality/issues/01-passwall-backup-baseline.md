# 01 — Establish PassWall backup & rollback baseline

**What to build:** Before any proxy node change, create timestamped backups of the router's PassWall config and the proxy monitor script, and verify the restore path works. This is the safety net every later change relies on — any ticket in this effort must be revertible in seconds.

**Blocked by:** None — can start immediately

**Status:** ready-for-agent

- [ ] A timestamped backup of the PassWall config exists on the router before any node changes
- [ ] A backup of the proxy monitor script exists alongside it
- [ ] The restore procedure (restore both files + restart PassWall) is verified to return the system to the pre-change state
- [ ] The backup filenames follow the existing naming convention on the router
