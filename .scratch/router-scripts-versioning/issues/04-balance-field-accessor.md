# 04 — Balance field accessor (kill the duplicated sed extraction)
**What to build:** The nine-line `echo "$bf" | sed -n 's/^pct=//p'`-style extraction from
`hn_balance_fields` output is byte-identical in botcmd.sh:226-233 and routerapi_lib.sh:283-291,
plus a partial copy in the dashboard (botcmd.sh:104-107). Add a field accessor to hnlib — e.g.
`hn_balance_field <fields> <name>` — and switch all three call sites to it. The field-name
knowledge lives in one place, so the next ISP report change is one edit in the reader.
**Blocked by:** 01 — callers are versioned before their extraction moves
**Status:** ready-for-agent
