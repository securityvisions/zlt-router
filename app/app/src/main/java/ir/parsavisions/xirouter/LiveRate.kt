package ir.parsavisions.xirouter

/** Throughput from two cumulative byte samples. */
data class LiveRate(val rxBytesPerSec: Long, val txBytesPerSec: Long)

object LiveRates {
    fun rate(prevRx: Long, prevTx: Long, currRx: Long, currTx: Long, deltaMillis: Long): LiveRate {
        val secs = deltaMillis / 1000.0
        if (secs <= 0) return LiveRate(0, 0)
        return LiveRate(
            rxBytesPerSec = ((currRx - prevRx).coerceAtLeast(0) / secs).toLong(),
            txBytesPerSec = ((currTx - prevTx).coerceAtLeast(0) / secs).toLong(),
        )
    }
}
