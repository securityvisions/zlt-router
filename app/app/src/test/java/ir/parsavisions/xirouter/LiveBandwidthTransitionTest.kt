package ir.parsavisions.xirouter

import org.junit.Assert.assertEquals
import org.junit.Test

class LiveBandwidthTransitionTest {
    private val wan = LiveCounters(1_000, 500)

    @Test
    fun `failed interval resets baseline and does not bridge rates`() {
        val transitions = LiveBandwidthTransitions()
        transitions.transition(sample(1_000, wan, device("a", 100, 50)), receivedAtMillis = 10)
        transitions.transition(sample(2_000, LiveCounters(2_000, 1_000), device("a", 200, 100)), receivedAtMillis = 20)

        val stale = transitions.failed()
        assertEquals(LiveBandwidthStatus.Stale, stale.status)
        assertEquals(LiveRate(1_000, 500), stale.wan)

        val baseline = transitions.transition(sample(4_000, LiveCounters(4_000, 2_000), device("a", 400, 200)), receivedAtMillis = 40)
        assertEquals(LiveBandwidthStatus.Initializing, baseline.status)
        assertEquals(LiveRate(0, 0), baseline.wan)
        assertEquals(emptyMap<String, LiveRate>(), baseline.deviceRates)
        assertEquals(emptyMap<String, List<Float>>(), baseline.histories)
    }

    @Test
    fun `lifecycle stop invalidates baseline without reporting a network failure`() {
        val transitions = LiveBandwidthTransitions()
        transitions.transition(sample(1_000, wan, device("a", 100, 50)), receivedAtMillis = 10)
        transitions.transition(sample(2_000, LiveCounters(2_000, 1_000), device("a", 200, 100)), receivedAtMillis = 20)

        transitions.stopped()
        val restarted = transitions.transition(
            sample(10_000, LiveCounters(10_000, 5_000), device("a", 1_000, 500)),
            receivedAtMillis = 100,
        )

        assertEquals(LiveBandwidthStatus.Initializing, restarted.status)
        assertEquals(LiveRate(0, 0), restarted.wan)
        assertEquals(emptyMap<String, LiveRate>(), restarted.deviceRates)
    }

    @Test
    fun `non-increasing timestamp establishes a fresh baseline`() {
        val transitions = LiveBandwidthTransitions()
        transitions.transition(sample(2_000, wan, device("a", 100, 50)), 10)
        transitions.transition(sample(3_000, LiveCounters(2_000, 1_000), device("a", 200, 100)), 20)

        val state = transitions.transition(sample(3_000, LiveCounters(3_000, 1_500), device("a", 300, 150)), 30)

        assertEquals(LiveBandwidthStatus.Initializing, state.status)
        assertEquals(LiveRate(0, 0), state.wan)
        assertEquals(emptyMap<String, LiveRate>(), state.deviceRates)
        assertEquals(emptyMap<String, List<Float>>(), state.histories)
    }

    @Test
    fun `WAN reset zeros only WAN rate`() {
        val transitions = LiveBandwidthTransitions()
        transitions.transition(sample(1_000, LiveCounters(10_000, 10_000), device("a", 100, 100)), 10)

        val state = transitions.transition(sample(2_000, LiveCounters(100, 50), device("a", 600, 300)), 20)

        assertEquals(LiveBandwidthStatus.Live, state.status)
        assertEquals(LiveRate(0, 0), state.wan)
        assertEquals(LiveRate(500, 200), state.deviceRates["a"])
    }

    @Test
    fun `per-Device reset zeros its rate and clears only its history`() {
        val transitions = LiveBandwidthTransitions()
        transitions.transition(sample(1_000, wan, device("a", 100, 100), device("b", 100, 100)), 10)
        transitions.transition(sample(2_000, LiveCounters(2_000, 1_000), device("a", 200, 200), device("b", 200, 200)), 20)

        val state = transitions.transition(sample(3_000, LiveCounters(3_000, 1_500), device("a", 10, 10), device("b", 300, 300)), 30)

        assertEquals(LiveRate(0, 0), state.deviceRates["a"])
        assertEquals(listOf(0f), state.histories["a"])
        assertEquals(listOf(100f, 100f), state.histories["b"])
    }

    @Test
    fun `new Device starts at zero and disappeared Device is removed`() {
        val transitions = LiveBandwidthTransitions()
        transitions.transition(sample(1_000, wan, device("a", 100, 100)), 10)
        transitions.transition(sample(2_000, LiveCounters(2_000, 1_000), device("a", 200, 200)), 20)

        val changed = transitions.transition(sample(3_000, LiveCounters(3_000, 1_500), device("b", 900, 800)), 30)
        assertEquals(mapOf("b" to LiveRate(0, 0)), changed.deviceRates)
        assertEquals(mapOf("b" to listOf(0f)), changed.histories)

        val reappeared = transitions.transition(sample(4_000, LiveCounters(4_000, 2_000), device("a", 500, 500), device("b", 1_000, 900)), 40)
        assertEquals(LiveRate(0, 0), reappeared.deviceRates["a"])
        assertEquals(listOf(0f), reappeared.histories["a"])
    }

    @Test
    fun `history is bounded`() {
        val transitions = LiveBandwidthTransitions(historyLimit = 3)
        transitions.transition(sample(0, LiveCounters(0, 0), device("a", 0, 0)), 0)
        transitions.transition(sample(1_000, wan, device("a", 100, 0)), 1)
        transitions.transition(sample(2_000, LiveCounters(2_000, 1_000), device("a", 300, 0)), 2)
        transitions.transition(sample(3_000, LiveCounters(3_000, 1_500), device("a", 600, 0)), 3)
        val state = transitions.transition(sample(4_000, LiveCounters(4_000, 2_000), device("a", 1_000, 0)), 4)

        assertEquals(listOf(200f, 300f, 400f), state.histories["a"])
    }

    @Test
    fun `failure is offline before success and stale after success`() {
        val transitions = LiveBandwidthTransitions()
        assertEquals(LiveBandwidthStatus.Offline, transitions.failed().status)

        transitions.transition(sample(1_000, wan), receivedAtMillis = 0)
        val stale = transitions.failed()

        assertEquals(LiveBandwidthStatus.Stale, stale.status)
        assertEquals(0L, stale.lastSuccessMillis)
    }

    private fun sample(ts: Long, wan: LiveCounters, vararg devices: LiveDeviceCounters) =
        LiveBandwidthSample(ts, wan, devices.toList())

    private fun device(mac: String, rx: Long, tx: Long) = LiveDeviceCounters(mac, rx, tx)
}
