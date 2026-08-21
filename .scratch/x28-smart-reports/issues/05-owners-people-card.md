# 05 — Owner assignment + per-person Jalali month card

**What to build:** Monthly consumption becomes attributable to people, in the calendar the family actually lives by. A root-only owner config maps each device MAC → person; a bot `/owner` flow lists assignments and assigns/reassigns/unassigns devices from chat. At daily-roll time — before day-files hit their 35-day prune — a permanent per-owner daily total is appended, so completed months stay computable forever. `/people` renders the current Jalali month as a Card: per-person GB + Toman rows (Persian month label), an "unassigned" bucket for unknown MACs, and a total that reconciles with overall usage.

**Blocked by:** 01 — Jalali module (month keying/labels) and the batch snapshot. Deliberately independent of 02–04.

**Status:** resolved

- [x] Owner config parsing is a pure function (MAC→person); device copy is root-only — `hn_owner_of` in hnlib, 23 tests
- [x] `/owner` flow from chat: list, assign, reassign, unassign; invalid/unknown MACs answered with guidance, not silence — `x28-owners.sh`, bot `/owner`
- [x] Per-owner daily roll is appended at roll time *before* prune; format keyed by Gregorian day so any Jalali range can be summed via the calendar module — `usage-collect.sh` roll now writes `owners/YYYY-MM-DD` via `hn_owner_of`, bound before prune
- [x] Aggregation function unit-tested over fixture rollups: multi-person, multi-device per person, reassignment mid-month, unassigned bucket — `x28-people.sh` with USAGE_DIR fixtures
- [x] Prune simulation: deleting old day-files does not change the people report (rollup survives)
- [x] `/people` Card: current Jalali month, Persian month name, persons sorted by usage desc, unassigned row, total reconciling with usage totals — `x28-people.sh` + bot `/people` + `/month`

## Comments

Owners at `/data/proxy/owners.conf` (600), per-owner daily files at `/data/proxy/usage/owners/`. Friday/weekly and monthly reports share the same Jalali month keying.
