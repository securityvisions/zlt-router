# 04 — Extract calendar + time module into cal-lib.sh

**What to build:** Jalali↔Gregorian conversion, Persian month labels, month-range computation, clock-skew validation, HTTP date epoch parsing, and bar rendering move from hnlib.sh into `cal-lib.sh`. This is the first hnlib split — proving the pattern for the remaining splits. A thin re-export in hnlib keeps existing callers green during migration.

**Blocked by:** None — independent of bot split.

**Status:** ready-for-agent

- [ ] cal-lib.sh exports: hn_greg_to_jalali, hn_jalali_to_greg, hn_jalali_month_range, hn_jalali_month_label, hn_clock_skew_ok, hn_http_date_epoch, bar
- [ ] hnlib sources cal-lib.sh and re-exports (callers unaffected)
- [ ] test_jalali.sh + relevant test_hn.sh asserts pass unchanged
- [ ] New test_cal_lib.sh runs the same assertions against the new module directly
