package ir.parsavisions.xirouter

import org.junit.Assert.assertEquals
import org.junit.Test
import java.time.LocalDate
import java.time.ZoneId

/** Known values for the vendored Borkowski/Jalali conversion, independent of the algorithm. */
class JalaliTest {

    /** The Tehran day (epoch-day count) of a Gregorian date at noon Tehran time. */
    private fun tehranDayOf(y: Int, m: Int, d: Int): Long {
        val ms = LocalDate.of(y, m, d).atStartOfDay(ZoneId.of("Asia/Tehran")).toInstant().toEpochMilli()
        return tehranDay(ms)
    }

    @Test fun `anchors - Nowruz is March 21 for 1400 and 1405`() {
        assertEquals(JalaliDate(1400, 1, 1), jalaliOf(tehranDayOf(2021, 3, 21)))
        assertEquals(JalaliDate(1405, 1, 1), jalaliOf(tehranDayOf(2026, 3, 21)))
    }

    @Test fun `a fixed summer Saturday in Mordad 1405`() {
        // 1405/05/22 == 2026-08-13 (Mordad 1 = 23 July 2026)
        assertEquals(JalaliDate(1405, 5, 22), jalaliOf(tehranDayOf(2026, 8, 13)))
    }

    @Test fun `leap-year Esfand lengths are 30 (1403) and 29 (1404)`() {
        assertEquals(30, jalaliMonthLength(1403, 12))
        assertEquals(29, jalaliMonthLength(1404, 12))
        assertEquals(31, jalaliMonthLength(1405, 6))
        assertEquals(30, jalaliMonthLength(1405, 7))
    }

    @Test fun `round-trip jalaliDay to jalaliOf`() {
        assertEquals(JalaliDate(1405, 5, 22), jalaliOf(jalaliDay(1405, 5, 22)))
        assertEquals(JalaliDate(1398, 12, 29), jalaliOf(jalaliDay(1398, 12, 29)))
        assertEquals(JalaliDate(1410, 1, 1), jalaliOf(jalaliDay(1410, 1, 1)))
    }

    @Test fun `month start of a mid-month day`() {
        assertEquals(jalaliDay(1405, 5, 1), jalaliMonthStart(jalaliDay(1405, 5, 22)))
        assertEquals(jalaliDay(1405, 12, 1), jalaliMonthStart(jalaliDay(1405, 12, 5)))
    }

    @Test fun `months back spans a year boundary`() {
        // Mordad 1405 minus 8 months = Azar 1404
        assertEquals(jalaliDay(1404, 9, 1), jalaliMonthsBack(jalaliDay(1405, 5, 22), 8))
        // Farvardin 1405 minus 1 month = Esfand 1404
        assertEquals(jalaliDay(1404, 12, 1), jalaliMonthsBack(jalaliDay(1405, 1, 15), 1))
    }

    @Test fun `tehran day boundary after midnight is still the previous UTC day`() {
        // 2026-08-13 00:30 Tehran = 2026-08-12 21:00 UTC -> the Tehran *day* is Aug 13
        val ms = LocalDate.of(2026, 8, 13).atStartOfDay(ZoneId.of("Asia/Tehran"))
            .plusMinutes(30).toInstant().toEpochMilli()
        assertEquals(JalaliDate(1405, 5, 22), jalaliOf(tehranDay(ms)))
    }

    @Test fun `month label formats Persian digits`() {
        assertEquals("مرداد ۱۴۰۵", jalaliMonthLabel(1405, 5))
        assertEquals("فروردین ۱۴۰۱", jalaliMonthLabel(1401, 1))
    }

    @Test fun `invalid Jalali month input renders safely`() {
        assertEquals(null, parseJalaliMonthKey("broken"))
        assertEquals(null, parseJalaliMonthKey("1405/13"))
        assertEquals("ماه نامعتبر", jalaliMonthLabel(1405, 13))
        assertEquals("ماه نامعتبر", jalaliMonthKeyLabel("bad"))
    }
}