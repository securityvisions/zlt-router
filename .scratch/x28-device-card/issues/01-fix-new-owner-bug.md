# 01 — Fix `__new__` owner placeholder bug

**What to build:** Reject `__new__` as a person name in the action CGI (server-side validation). Fix the existing `__new__` entry in owners.conf on the device. The JS new-person flow should collect the name BEFORE sending the assign request.

**Blocked by:** None.

**Status:** ready-for-agent

- [ ] CGI rejects `__new__` as person name with error
- [ ] Existing `__new__` entry in device owners.conf corrected
- [ ] JS new-person flow is atomic (name collected before request sent)
