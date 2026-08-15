package ir.parsavisions.xirouter

/** Android-free cumulative counters consumed by the Live bandwidth transition module. */
data class LiveCounters(val rxBytes: Long, val txBytes: Long)

data class LiveDeviceCounters(val mac: String, val rxBytes: Long, val txBytes: Long)

data class LiveBandwidthSample(
    val timestampMillis: Long,
    val wan: LiveCounters,
    val devices: List<LiveDeviceCounters>,
)

enum class LiveBandwidthStatus { Initializing, Live, Stale, Offline }

data class LiveBandwidthState(
    val status: LiveBandwidthStatus = LiveBandwidthStatus.Initializing,
    val lastSuccessMillis: Long = 0,
    val wan: LiveRate = LiveRate(0, 0),
    val deviceRates: Map<String, LiveRate> = emptyMap(),
    val histories: Map<String, List<Float>> = emptyMap(),
)

/**
 * Deterministic state transitions for Live bandwidth samples and polling failures.
 * A failure or non-increasing timestamp invalidates the rate baseline, so intervals are never bridged.
 */
class LiveBandwidthTransitions(private val historyLimit: Int = 60) {
    init {
        require(historyLimit > 0) { "historyLimit must be positive" }
    }

    var state: LiveBandwidthState = LiveBandwidthState()
        private set

    private var baseline: LiveBandwidthSample? = null
    private var hasSucceeded = false

    fun transition(sample: LiveBandwidthSample, receivedAtMillis: Long): LiveBandwidthState {
        val previous = baseline
        hasSucceeded = true
        state = if (previous == null || sample.timestampMillis <= previous.timestampMillis) {
            LiveBandwidthState(lastSuccessMillis = receivedAtMillis)
        } else {
            rates(previous, sample, receivedAtMillis)
        }
        baseline = sample
        return state
    }

    fun failed(): LiveBandwidthState {
        baseline = null
        state = state.copy(
            status = if (hasSucceeded) LiveBandwidthStatus.Stale else LiveBandwidthStatus.Offline,
        )
        return state
    }

    /** End an active polling interval without treating lifecycle inactivity as a network failure. */
    fun stopped() {
        baseline = null
    }

    private fun rates(
        previous: LiveBandwidthSample,
        sample: LiveBandwidthSample,
        receivedAtMillis: Long,
    ): LiveBandwidthState {
        val elapsed = sample.timestampMillis - previous.timestampMillis
        val wanReset = sample.wan.rxBytes < previous.wan.rxBytes || sample.wan.txBytes < previous.wan.txBytes
        val wanRate = if (wanReset) LiveRate(0, 0) else LiveRates.rate(
            previous.wan.rxBytes,
            previous.wan.txBytes,
            sample.wan.rxBytes,
            sample.wan.txBytes,
            elapsed,
        )
        val previousDevices = previous.devices.associateBy { it.mac }
        val resetDevices = mutableSetOf<String>()
        val deviceRates = sample.devices.associate { device ->
            val old = previousDevices[device.mac]
            val reset = old != null && (device.rxBytes < old.rxBytes || device.txBytes < old.txBytes)
            if (reset) resetDevices += device.mac
            device.mac to if (old == null || reset) LiveRate(0, 0) else LiveRates.rate(
                old.rxBytes,
                old.txBytes,
                device.rxBytes,
                device.txBytes,
                elapsed,
            )
        }
        val histories = deviceRates.mapValues { (mac, rate) ->
            val existing = if (mac in resetDevices) emptyList() else state.histories[mac].orEmpty()
            (existing + rate.rxBytesPerSec.toFloat()).takeLast(historyLimit)
        }
        return LiveBandwidthState(
            status = LiveBandwidthStatus.Live,
            lastSuccessMillis = receivedAtMillis,
            wan = wanRate,
            deviceRates = deviceRates,
            histories = histories,
        )
    }
}
