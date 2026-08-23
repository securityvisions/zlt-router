# 03 — Action CGI endpoints (validated mutations through proven scripts)

**What to build:** CGI shell scripts in the dashboard's cgi-bin that accept POST requests, validate input strictly (MAC regex, PLMN whitelist, enum values), call the SAME proven scripts the Telegram bot uses (x28-owners.sh assign/unassign/rename, operator-watchdog.sh switch, x28-rescue.sh switch), and return JSON responses. Every action requires a confirmation token embedded in the request body (generated when the page loads). No raw system access.

**Blocked by:** 02 — needs the HTTP server to route CGI requests.

**Status:** ready-for-agent

- [ ] POST /api/action/assign → x28-owners.sh assign (validates MAC format, person name charset)
- [ ] POST /api/action/unassign → x28-owners.sh unassign
- [ ] POST /api/action/switch → operator-watchdog.sh switch (PLMN must be 43211 or 43220)
- [ ] POST /api/action/rescue → x28-rescue.sh switch on|off
- [ ] POST /api/action/adblock → toggle adblock service
- [ ] POST /api/action/reboot → reboot (requires confirm=true in body)
- [ ] Every endpoint validates input before calling any script; invalid input returns {"error":"..."} with HTTP 400
- [ ] CSRF token checked on every POST; missing/wrong token returns HTTP 403
- [ ] All actions logged to dashboard audit log
