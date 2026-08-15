package ir.parsavisions.xirouter

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationEventsTest {
    private val healthy = RouterSnapshot(
        balanceTier = 0, proxyUp = true, deviceMacs = setOf("a", "b"),
        diskPct = 50, uptimeSecs = 100_000, drainRateGbh = 0.0, remainingGb = 80.0,
    )

    @Test
    fun firstPollBaselinesSilently() {
        assertEquals(emptyList<AlertEvent>(), NotificationEvents.events(null, healthy))
    }

    @Test
    fun noChangeYieldsNothing() {
        assertEquals(emptyList<AlertEvent>(), NotificationEvents.events(healthy, healthy))
    }

    @Test
    fun balanceEscalationFires() {
        assertEquals(
            listOf(AlertEvent.BalanceUrgent),
            NotificationEvents.events(healthy, healthy.copy(balanceTier = 3)),
        )
    }

    @Test
    fun balanceExhaustedMapsToItsOwnEvent() {
        assertEquals(
            listOf(AlertEvent.BalanceExhausted),
            NotificationEvents.events(healthy, healthy.copy(balanceTier = 4)),
        )
    }

    @Test
    fun balanceDeescalationIsSilent() {
        assertEquals(emptyList<AlertEvent>(), NotificationEvents.events(healthy.copy(balanceTier = 3), healthy))
    }

    @Test
    fun proxyTransitionFires() {
        assertEquals(
            listOf(AlertEvent.ProxyDown),
            NotificationEvents.events(healthy, healthy.copy(proxyUp = false)),
        )
    }

    @Test
    fun newDeviceFires() {
        assertEquals(
            listOf(AlertEvent.NewDevice),
            NotificationEvents.events(healthy, healthy.copy(deviceMacs = setOf("a", "b", "c"))),
        )
    }

    @Test
    fun diskCrossingFires() {
        assertEquals(listOf(AlertEvent.DiskHigh), NotificationEvents.events(healthy, healthy.copy(diskPct = 90)))
    }

    @Test
    fun diskAlreadyHighIsSilent() {
        assertEquals(emptyList<AlertEvent>(), NotificationEvents.events(healthy.copy(diskPct = 90), healthy.copy(diskPct = 91)))
    }

    @Test
    fun rebootDetectedViaUptimeDrop() {
        assertEquals(listOf(AlertEvent.Reboot), NotificationEvents.events(healthy, healthy.copy(uptimeSecs = 60)))
    }

    @Test
    fun highDrainFiresWhenUnderRemaining() {
        assertEquals(
            listOf(AlertEvent.HighDrain),
            NotificationEvents.events(healthy, healthy.copy(drainRateGbh = 6.0, remainingGb = 20.0)),
        )
    }

    @Test
    fun highDrainWithEnoughDataIsSilent() {
        assertEquals(
            emptyList<AlertEvent>(),
            NotificationEvents.events(healthy, healthy.copy(drainRateGbh = 6.0, remainingGb = 50.0)),
        )
    }

    @Test
    fun drainRateFromSeriesSkipsPackageAdds() {
        val points = listOf(BalancePoint("2026-08-01", 150.0), BalancePoint("2026-08-02", 149.0), BalancePoint("2026-08-03", 151.0))
        val gbh = NotificationEvents.drainRateGbh(points)
        // last two: 149 -> 151 is a rise (skipped); nothing dropped, rate ~0
        assertEquals(0.0, gbh, 0.001)
    }

    @Test
    fun drainRateUsesNewestPair() {
        val points = listOf(BalancePoint("2026-08-01", 150.0), BalancePoint("2026-08-02", 147.0))
        // 3 GB over 1 day = 3 GB/day = 0.125 GB/h
        assertEquals(0.125, NotificationEvents.drainRateGbh(points), 0.001)
    }
}

class BillReadyTest {
    @Test
    fun firstOfMonthIsDueOnce() {
        assertEquals(true, BillReady.due("2026-09-01", null))
        assertEquals(false, BillReady.due("2026-09-01", "2026-09-01"))
    }

    @Test
    fun otherDaysAreNeverDue() {
        assertEquals(false, BillReady.due("2026-09-15", null))
        assertEquals(false, BillReady.due("2026-09-02", null))
    }

    @Test
    fun newMonthFiresAgain() {
        assertEquals(true, BillReady.due("2026-10-01", "2026-09-01"))
    }
}

class UptimeTest {
    @Test
    fun parsesDaysHoursMinutes() {
        assertEquals(3 * 86_400L + 4 * 3_600L + 12 * 60L, Uptime.parse("3 days, 4:12"))
    }

    @Test
    fun parsesPlainTime() {
        assertEquals(4 * 3_600L + 12 * 60L, Uptime.parse("4:12"))
    }

    @Test
    fun nullMeansUnknown() {
        assertEquals(Long.MAX_VALUE, Uptime.parse(null))
    }
}
