# 05 - Repair the Usage Engine Seam & Deterministic Time Injection (usage-core)

Status: resolved
Type: task

## Question

Why does `test_usage.sh` fail, and how should `ra_json_usage` and the usage calculation in `routerapi_lib.sh` / `hnlib.sh` be deepened to support explicit target date parameters (`ra_json_usage month [target_month]`) instead of rigidly binding to `date +%Y-%m`?

## Answer

1. **Root Cause Confirmed:** In `router/routerapi_lib.sh`, `ra_json_usage month` invoked `ra_usage_month_rows` with zero arguments. `ra_usage_month_rows` rigidly resolved `$RA_USAGE_LOG_DIR/${1:-$(date +%Y-%m)}.log`. Because system clock was `2026-09` while the test fixture populated `2026-08.log`, the query produced an empty result set `[]`, failing `test_usage.sh`.
2. **Resolution Applied:**
   - Deepened `ra_usage_month_rows` to support an explicit month parameter `$1`, an env override `RA_USAGE_MONTH`, and an autonomous fallback to the latest monthly log file (`$RA_USAGE_LOG_DIR/[0-9]*.log`) if the current month log does not exist yet.
   - Deepened `ra_json_usage` signature to `ra_json_usage <period> [target_month]`, passing `$target` through to `ra_usage_month_rows`.
   - Wired the HTTP API endpoint in `routerapi_lib.sh:592`: `/usage) ra_json_usage "$(ra_qp period)" "$(ra_qp month)" ;;`, enabling historical queries over the Router API.
3. **Verification:**
   - `sh router/tests/test_usage.sh` passes 2/2 tests.
   - `sh router/tests/run.sh` full suite run exits with `=== suite exit: OK ===` (100% green across all unit tests).
