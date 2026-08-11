# 06 — Final build, test suite, and signed APK

**What to build:** a full build of the rewritten app to verify everything compiles, all 39 unit tests pass (Format, LiveRate, BalanceTier, ChartMath, NotificationEvents, BillReady, Uptime), the debug APK launches without crashes, and a signed release APK is produced. This is the integration ticket that catches any cross-ticket issues.

**Blocked by:** 01, 02, 03, 04, 05

**Status:** ready-for-agent

- [ ] `./gradlew :app:assembleDebug` compiles clean (no Kotlin errors, no R8 warnings about missing keep rules)
- [ ] `./gradlew :app:testDebugUnitTest` — all 39 tests pass (no regressions from UI changes)
- [ ] `./gradlew :app:assembleRelease` produces a signed release APK (keystore + signing config already in place)
- [ ] APK signature verified (`apksigner verify`)
- [ ] Dark theme renders correctly; light theme follows system; RTL is forced; floating tab bar navigates correctly; back button works on all detail screens; charts animate; live bandwidth polls without stacking
