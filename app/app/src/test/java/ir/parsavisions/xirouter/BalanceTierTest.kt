package ir.parsavisions.xirouter

import org.junit.Assert.assertEquals
import org.junit.Test

class BalanceTierTest {
    @Test
    fun exhaustedBelowHalfGiga() {
        assertEquals(4, BalanceTier.decide(0.04, 100.0, 300, 999.0))
    }

    @Test
    fun urgentOnLowRemainingOrCloseExpiry() {
        assertEquals(3, BalanceTier.decide(2.0, 50.0, 10, 999.0))
        assertEquals(3, BalanceTier.decide(20.0, 50.0, 2, 999.0))
        assertEquals(3, BalanceTier.decide(20.0, 50.0, 10, 5.0))
    }

    @Test
    fun warnOnThresholds() {
        assertEquals(2, BalanceTier.decide(8.0, 50.0, 10, 999.0))
        assertEquals(2, BalanceTier.decide(20.0, 50.0, 5, 999.0))
        assertEquals(2, BalanceTier.decide(20.0, 50.0, 10, 12.0))
    }

    @Test
    fun noticeOnPctOrProjection() {
        assertEquals(1, BalanceTier.decide(20.0, 20.0, 10, 999.0))
        assertEquals(1, BalanceTier.decide(20.0, 50.0, 10, 25.0))
    }

    @Test
    fun healthyIsNone() {
        assertEquals(0, BalanceTier.decide(80.0, 90.0, 200, 999.0))
    }
}
