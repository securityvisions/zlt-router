package ir.parsavisions.xirouter

import org.junit.Assert.assertEquals
import org.junit.Test

class LiveRateTest {
    @Test
    fun rateIsBytesPerSecond() {
        val r = LiveRates.rate(0, 0, 1000, 500, 1000)
        assertEquals(LiveRate(1000, 500), r)
    }

    @Test
    fun zeroElapsedYieldsZero() {
        assertEquals(LiveRate(0, 0), LiveRates.rate(0, 0, 1000, 500, 0))
    }

    @Test
    fun counterResetIsClampedToZero() {
        assertEquals(LiveRate(0, 0), LiveRates.rate(9000, 9000, 1000, 1000, 2000))
    }

    @Test
    fun longerWindowScalesDown() {
        assertEquals(LiveRate(500, 250), LiveRates.rate(0, 0, 1000, 500, 2000))
    }
}
