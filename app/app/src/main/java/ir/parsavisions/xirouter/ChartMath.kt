package ir.parsavisions.xirouter

import kotlin.math.abs

/** Pure chart calculations shared by Compose charts and unit tests. */
object ChartMath {
    data class TimedValue(val ts: Long, val value: Double)
    data class DailyValue(val tehranDay: Long, val value: Double)

    /** A stable Tehran-local bucket. UTC division is wrong around 00:00–03:30 Tehran. */
    fun tehranBucket(ts: Long, bucketMillis: Long): Long {
        require(bucketMillis > 0)
        val shifted = ts + TEHRAN_OFFSET_MS
        val quotient = shifted / bucketMillis
        return if (shifted < 0 && shifted % bucketMillis != 0L) quotient - 1 else quotient
    }

    /** Merges chronologically; the latest local sample replaces router data in its Tehran bucket. */
    fun mergeSamples(
        router: List<TimedValue>,
        local: List<TimedValue>,
        bucketMillis: Long,
    ): List<TimedValue> {
        val merged = sortedMapOf<Long, TimedValue>()
        router.sortedBy { it.ts }.forEach { merged[tehranBucket(it.ts, bucketMillis)] = it }
        local.sortedBy { it.ts }.forEach { merged[tehranBucket(it.ts, bucketMillis)] = it }
        return merged.values.sortedBy { it.ts }
    }

    /** Timestamp-aware normalized points; irregular samples retain their real horizontal spacing. */
    fun timedPlot(values: List<TimedValue>, minY: Double, maxY: Double): List<Pair<Float, Float>> {
        if (values.isEmpty()) return emptyList()
        val sorted = values.sortedBy { it.ts }
        val timeSpan = (sorted.last().ts - sorted.first().ts).coerceAtLeast(1L)
        val ySpan = (maxY - minY).coerceAtLeast(1e-6)
        return sorted.map {
            ((it.ts - sorted.first().ts).toFloat() / timeSpan) to
                ((it.value - minY) / ySpan).toFloat().coerceIn(0f, 1f)
        }
    }

    fun plot(values: List<Double>): List<Pair<Float, Float>> {
        if (values.isEmpty()) return emptyList()
        val min = values.min()
        val span = (values.max() - min).coerceAtLeast(1e-6)
        return values.mapIndexed { index, value ->
            val x = if (values.size == 1) 0.5f else index.toFloat() / (values.size - 1)
            x to ((value - min) / span).toFloat()
        }
    }

    /**
     * Converts a cumulative counter to increments. A reset contributes the new counter value;
     * an implausibly large sampling gap contributes zero rather than inventing usage.
     */
    fun cumulativeIncrements(samples: List<TimedValue>, maxGapMillis: Long): List<TimedValue> {
        if (samples.size < 2) return emptyList()
        val sorted = samples.sortedBy { it.ts }
        return sorted.zipWithNext().map { (before, after) ->
            val gap = after.ts - before.ts
            val increment = when {
                gap <= 0 || gap > maxGapMillis -> 0.0
                after.value >= before.value -> after.value - before.value
                else -> after.value.coerceAtLeast(0.0)
            }
            TimedValue(after.ts, increment)
        }
    }

    /** Daily columns for the elapsed part of one Jalali month, including zero-usage days. */
    fun jalaliMonthDailyUsage(
        cumulative: List<TimedValue>,
        nowMillis: Long,
        maxGapMillis: Long = 3 * 3_600_000L,
    ): List<DailyValue> {
        val today = tehranDay(nowMillis)
        val start = jalaliMonthStart(today)
        val totals = cumulativeIncrements(cumulative, maxGapMillis)
            .filter { tehranDay(it.ts) in start..today }
            .groupBy { tehranDay(it.ts) }
            .mapValues { (_, values) -> values.sumOf { it.value } }
        return (start..today).map { DailyValue(it, totals[it] ?: 0.0) }
    }

    /** Linear exhaustion estimate using the full observed span; null for flat/rising balance. */
    fun projectedExhaustion(samples: List<TimedValue>): Long? {
        val sorted = samples.sortedBy { it.ts }
        if (sorted.size < 2) return null
        val first = sorted.first()
        val last = sorted.last()
        val elapsed = last.ts - first.ts
        val used = first.value - last.value
        if (elapsed <= 0 || used <= 0.0 || last.value <= 0.0) return null
        val projected = last.ts + (last.value / used * elapsed).toLong()
        return projected.takeIf { it > last.ts }
    }

    fun nearestIndex(samples: List<TimedValue>, fraction: Float): Int {
        if (samples.isEmpty()) return -1
        val sorted = samples.sortedBy { it.ts }
        val target = sorted.first().ts + ((sorted.last().ts - sorted.first().ts) * fraction.coerceIn(0f, 1f)).toLong()
        return sorted.indices.minByOrNull { abs(sorted[it].ts - target) } ?: -1
    }

    fun maxValue(values: List<Double>): Double = values.maxOrNull() ?: 0.0

    fun barSlots(count: Int): List<Pair<Float, Float>> {
        if (count <= 0) return emptyList()
        val width = 1f / count
        return List(count) { index -> index * width to width }
    }
}
