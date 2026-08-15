package ir.parsavisions.xirouter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class ChartMathTest {
    @Test
    fun emptyYieldsEmpty() {
        assertEquals(emptyList<Pair<Float, Float>>(), ChartMath.plot(emptyList()))
    }

    @Test
    fun singlePointCentersX() {
        val p = ChartMath.plot(listOf(5.0))
        assertEquals(1, p.size)
        assertEquals(0.5f, p[0].first)
    }

    @Test
    fun plotSpansMinToMax() {
        val p = ChartMath.plot(listOf(0.0, 10.0, 5.0))
        assertEquals(listOf(0f to 0f, 0.5f to 1f, 1f to 0.5f), p)
    }

    @Test
    fun flatValuesDoNotDivideByZero() {
        val p = ChartMath.plot(listOf(3.0, 3.0, 3.0))
        assertEquals(listOf(0f to 0f, 0.5f to 0f, 1f to 0f), p)
    }

    @Test
    fun maxValueAndBarSlots() {
        assertEquals(9.0, ChartMath.maxValue(listOf(1.0, 9.0, 3.0)), 0.0)
        assertEquals(listOf(0f to 0.5f, 0.5f to 0.5f), ChartMath.barSlots(2))
        assertEquals(emptyList<Pair<Float, Float>>(), ChartMath.barSlots(0))
    }

    @Test
    fun samplesMergeChronologicallyWithLocalPreferred() {
        val hour = 3_600_000L
        assertEquals(
            listOf(
                ChartMath.TimedValue(hour, 1.0),
                ChartMath.TimedValue(2 * hour + 1, 2.5),
                ChartMath.TimedValue(3 * hour, 3.0),
            ),
            ChartMath.mergeSamples(
                router = listOf(ChartMath.TimedValue(3 * hour, 3.0), ChartMath.TimedValue(2 * hour, 2.0)),
                local = listOf(ChartMath.TimedValue(hour, 1.0), ChartMath.TimedValue(2 * hour + 1, 2.5)),
                bucketMillis = hour,
            ),
        )
    }

    @Test
    fun dailyBucketsUseTehranMidnightNotUtc() {
        val day = 86_400_000L
        val tehran0030 = day - TEHRAN_OFFSET_MS + 30 * 60_000L
        assertEquals(1L, ChartMath.tehranBucket(tehran0030, day))
        assertEquals(0L, ChartMath.tehranBucket(tehran0030 - 60 * 60_000L, day))
    }

    @Test
    fun timedPlotPreservesIrregularTimestampSpacing() {
        val points = ChartMath.timedPlot(
            listOf(ChartMath.TimedValue(0, 0.0), ChartMath.TimedValue(10, 5.0), ChartMath.TimedValue(100, 10.0)),
            0.0,
            10.0,
        )
        assertEquals(0.1f, points[1].first, 0.0001f)
        assertEquals(0.5f, points[1].second, 0.0001f)
    }

    @Test
    fun cumulativeCounterHandlesResetAndGapWithoutSpikes() {
        val hour = 3_600_000L
        assertEquals(
            listOf(
                ChartMath.TimedValue(hour, 2.0),
                ChartMath.TimedValue(2 * hour, 1.0),
                ChartMath.TimedValue(10 * hour, 0.0),
            ),
            ChartMath.cumulativeIncrements(
                listOf(
                    ChartMath.TimedValue(0, 10.0),
                    ChartMath.TimedValue(hour, 12.0),
                    ChartMath.TimedValue(2 * hour, 1.0),
                    ChartMath.TimedValue(10 * hour, 50.0),
                ),
                maxGapMillis = 2 * hour,
            ),
        )
    }

    @Test
    fun dailyUsageIncludesOnlyElapsedDaysOfCurrentJalaliMonth() {
        val hour = 3_600_000L
        val start = jalaliDay(1405, 2, 1)
        val dayOneNoon = tehranDayStart(start) + 12 * hour
        val dayTwoNoon = dayOneNoon + 86_400_000L
        val daily = ChartMath.jalaliMonthDailyUsage(
            listOf(
                ChartMath.TimedValue(dayOneNoon, 4.0),
                ChartMath.TimedValue(dayOneNoon + hour, 5.5),
                ChartMath.TimedValue(dayTwoNoon, 8.0), // gap: do not invent 2.5 GB
            ),
            nowMillis = tehranDayStart(start + 1) + 20 * hour,
            maxGapMillis = 2 * hour,
        )
        assertEquals(listOf(1.5, 0.0), daily.map { it.value })
    }

    @Test
    fun projectsExhaustionOnlyForDecliningBalance() {
        val day = 86_400_000L
        assertEquals(
            10 * day,
            ChartMath.projectedExhaustion(listOf(ChartMath.TimedValue(0, 10.0), ChartMath.TimedValue(5 * day, 5.0))),
        )
        assertNull(ChartMath.projectedExhaustion(listOf(ChartMath.TimedValue(0, 5.0), ChartMath.TimedValue(day, 6.0))))
    }

    @Test
    fun nearestPointUsesTimeRatherThanListIndex() {
        assertEquals(
            1,
            ChartMath.nearestIndex(
                listOf(ChartMath.TimedValue(0, 0.0), ChartMath.TimedValue(90, 1.0), ChartMath.TimedValue(100, 2.0)),
                .8f,
            ),
        )
    }
}
