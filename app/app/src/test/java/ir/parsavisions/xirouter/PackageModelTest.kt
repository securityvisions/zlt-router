package ir.parsavisions.xirouter

import java.time.LocalDate
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class PackageModelTest {
    private fun dto(id: String, remain: Double = 20.0, status: String = "active") = PackageDto(
        id = id, provider = "ISP", name = "Router name", quota_gb = 100.0,
        remain_gb = remain, consumed_gb = 100 - remain, status = status,
    )

    @Test fun identityIsOpaqueAndDuplicatesAreDeterministic() {
        assertEquals(listOf("opaque:1"), PackageIdentity.unique(listOf(dto(""), dto("opaque:1"), dto("opaque:1", 9.0))).map { it.id })
    }

    @Test fun lifecycleConfirmsMissingThenArchivesAndReappearancePreservesMetadata() {
        val first = PackageLifecycle.merge(dto("opaque:1"), null, 10).copy(alias = "Mine", alertsMuted = true)
        val once = PackageLifecycle.missing(first)
        assertTrue(once.unconfirmed); assertFalse(once.archived)
        val twice = PackageLifecycle.missing(once)
        assertTrue(twice.unconfirmed); assertFalse(twice.archived)
        val archived = PackageLifecycle.missing(twice)
        assertTrue(archived.archived); assertFalse(archived.unconfirmed)
        val returned = PackageLifecycle.merge(dto("opaque:1", 8.0), archived, 20)
        assertFalse(returned.archived); assertFalse(returned.unconfirmed)
        assertEquals("Mine", returned.alias); assertTrue(returned.alertsMuted)
    }

    @Test fun insightsCalculatePercentExpiryAndDepletion() {
        val p = PackageLifecycle.merge(dto("x", 20.0), null, 1).copy(expiry = "2026-08-23")
        val value = PackageInsights.calculate(p, 2.0, LocalDate.of(2026, 8, 13))
        assertEquals(20, value.remainingPct); assertEquals(10L, value.daysToExpiry); assertEquals(10.0, value.depletionDays!!, 0.0)
    }

    @Test fun alertsAreThresholdCrossingDeterministicAndRespectMute() {
        val previous = PackageLifecycle.merge(dto("x", 21.0), null, 1)
        val current = PackageLifecycle.merge(dto("x", 20.0), previous, 2)
        assertEquals(listOf(PackageAlert("x", PackageAlertKind.LOW)), PackageAlerts.calculate(previous, current, true, 20))
        assertEquals(emptyList<PackageAlert>(), PackageAlerts.calculate(previous, current.copy(alertsMuted = true), true, 20))
        assertEquals(emptyList<PackageAlert>(), PackageAlerts.calculate(previous, current, false, 20))
    }

    @Test fun firstPackageSnapshotBaselinesSilently() {
        val first = PackageLifecycle.merge(dto("new", 1.0, "depleted"), null, 1)
        assertEquals(emptyList<PackageAlert>(), PackageAlerts.calculate(null, first, true, 20))
    }

    @Test fun alertsCoverNewReappearanceDepletionExpiryAndConfirmedDisappearance() {
        val newPackage = PackageLifecycle.merge(dto("new", 100.0), null, 2)
        assertEquals(listOf(PackageAlert("new", PackageAlertKind.NEW)), PackageAlerts.calculate(null, newPackage, true, 20, establishedBaseline = true))
        val previous = PackageLifecycle.merge(dto("x", 50.0), null, 1)
        val returned = PackageLifecycle.merge(dto("x", 45.0), previous.copy(archived = true), 2)
        assertEquals(listOf(PackageAlert("x", PackageAlertKind.NEW)), PackageAlerts.calculate(previous.copy(archived = true), returned, true, 20))
        assertEquals(listOf(PackageAlert("x", PackageAlertKind.DEPLETED)), PackageAlerts.calculate(previous, previous.copy(status = "depleted"), true, 20))
        val expiringBefore = previous.copy(expiry = "2026-08-20")
        val expiringNow = previous.copy(expiry = "2026-08-15")
        assertEquals(listOf(PackageAlert("x", PackageAlertKind.EXPIRY)), PackageAlerts.calculate(expiringBefore, expiringNow, true, 20, LocalDate.of(2026, 8, 13)))
        assertEquals(listOf(PackageAlert("x", PackageAlertKind.DISAPPEARED)), PackageAlerts.missing(previous.copy(missingSuccessCount = 2), PackageLifecycle.missing(previous.copy(missingSuccessCount = 2)), true))
    }

    @Test fun noCacheOrTimestampLessEmptyIsNotAuthoritative() {
        assertFalse(PackageSync.authoritative(BalanceResponse(cached = true, as_of_unix = 10)))
        assertFalse(PackageSync.authoritative(BalanceResponse(cached = false, as_of_unix = 0)))
        assertTrue(PackageSync.authoritative(BalanceResponse(cached = false, as_of_unix = 10)))
    }

    @Test fun stalePackageRowsAndMissingObservationsAreRejected() {
        val old = PackageLifecycle.merge(dto("x", 8.0), null, 200)
        assertFalse(PackageSync.acceptsRow(old, 199))
        assertTrue(PackageSync.acceptsRow(old, 200))
        assertFalse(PackageSync.acceptsMissing(old, 200))
        assertTrue(PackageSync.acceptsMissing(old, 201))
    }

    @Test fun packageAlertDeliveryFailureRetainsEventForSuccessfulRetry() {
        val pending = listOf(PackageAlert("x", PackageAlertKind.LOW))
        val afterFailure = PackageAlertDelivery.remaining(pending, NotificationDeliveryOutcome.Error)
        assertEquals(pending, afterFailure)
        assertEquals(emptyList<PackageAlert>(), PackageAlertDelivery.remaining(afterFailure, NotificationDeliveryOutcome.Delivered))
        assertEquals(emptyList<PackageAlert>(), PackageAlertDelivery.remaining(pending, NotificationDeliveryOutcome.Disabled))
        assertEquals(emptyList<PackageAlert>(), PackageAlertDelivery.remaining(pending, NotificationDeliveryOutcome.Unavailable))
    }

    @Test fun displayModeValidationFallsBackAndModesDiffer() {
        assertEquals(PackageDisplayMode.AGGREGATE, PackageDisplayMode.parse("bad"))
        assertEquals(3, PackageDisplayMode.entries.map { it.value }.distinct().size)
    }

    @Test fun historyComputesDailyConsumption() {
        val rows = listOf(
            PackageSnapshotEntity("x", 0, 100.0, 30.0, 70.0, "active", null),
            PackageSnapshotEntity("x", 86_400, 100.0, 28.0, 72.0, "active", null),
        )
        assertEquals(2.0, PackageInsights.dailyConsumption(rows), 0.0)
    }

    @Test fun importedFieldsCannotBeChangedByMetadataCopyPattern() {
        val current = PackageLifecycle.merge(dto("x", 20.0), null, 1)
        val edited = current.copy(alias = "Local", note = "note")
        assertEquals(current.remainGb, edited.remainGb); assertEquals(current.provider, edited.provider)
    }
}
