package ir.parsavisions.xirouter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class LedgerTest {

    // ── Pricing ──

    @Test fun `rate resolution uses frozen month rate then default`() {
        assertEquals(8000, Pricing.resolveRate(7700, 8000))
        assertEquals(7700, Pricing.resolveRate(7700, null))
        assertEquals(Pricing.DEFAULT_RATE, Pricing.resolveRate(Pricing.DEFAULT_RATE, null))
    }

    @Test fun `daily snapshots use the owner interval valid on each day`() {
        val usage = LedgerAggregation.usageByOwner(
            dailyUsage = listOf(
                DailyUsageValue(10, "a", 1.0),
                DailyUsageValue(11, "a", 2.0),
                DailyUsageValue(12, "a", 3.0),
                DailyUsageValue(12, "hidden", 9.0),
                DailyUsageValue(12, "unknown", 4.0),
            ),
            ownership = listOf(
                OwnershipInterval("a", "p1", 10, 12),
                OwnershipInterval("a", "p2", 12, null),
            ),
            visibleMacs = setOf("a", "unknown"),
            unassigned = "__unassigned__",
        )
        assertEquals(3.0, usage["p1"]!!, 0.001)
        assertEquals(3.0, usage["p2"]!!, 0.001)
        assertEquals(4.0, usage["__unassigned__"]!!, 0.001)
        assertEquals(3, usage.size)
    }

    @Test fun `pricing precedence is person then frozen month then current default`() {
        assertEquals(9_000, Pricing.resolveRate(7_700, 8_000, 9_000))
        assertEquals(8_000, Pricing.resolveRate(7_700, 8_000, null))
        assertEquals(7_700, Pricing.resolveRate(7_700, null, null))
    }

    @Test fun `open month follows changed current default while closed month keeps frozen rate`() {
        assertEquals(8_500, Pricing.resolveRate(default = 8_500, frozenMonthRate = null))
        assertEquals(7_700, Pricing.resolveRate(default = 8_500, frozenMonthRate = 7_700))
        assertEquals(9_000, Pricing.resolveRate(default = 8_500, frozenMonthRate = 7_700, personRate = 9_000))
    }

    @Test fun `reconciliation preserves manual fields and removes only untouched stale rows`() {
        val manual = ReconcileLine("p1", 1.0, 7_700, 8_000, 12_345, true, 2_000, "note", true)
        val paidStale = ReconcileLine("paid", 3.0, 7_700, 23_000, null, true, 23_000, "", false)
        val autoStale = ReconcileLine("stale", 3.0, 7_700, 23_000, null, false, 0, "", false)
        val result = LedgerReconciliation.reconcile(
            usageByPerson = mapOf("p1" to 2.0, "p2" to 1.0),
            existing = listOf(manual, paidStale, autoStale),
            defaultRate = 7_700,
            monthRate = 8_000,
            personRates = mapOf("p2" to 9_000),
        ).associateBy { it.personId }

        assertEquals(2.0, result.getValue("p1").usageGb, 0.001)
        assertEquals(12_345, result.getValue("p1").owedToman)
        assertEquals("note", result.getValue("p1").note)
        assertEquals(9_000, result.getValue("p2").rateUsed)
        assertTrue("paid" in result)
        assertTrue("stale" !in result)
    }

    @Test fun `ownership starts inclusively and ends exclusively`() {
        val usage = LedgerAggregation.usageByOwner(
            dailyUsage = listOf(
                DailyUsageValue(19, "mac", 1.0),
                DailyUsageValue(20, "mac", 2.0),
                DailyUsageValue(21, "mac", 4.0),
            ),
            ownership = listOf(OwnershipInterval("mac", "person", 20, 21)),
            visibleMacs = setOf("mac"),
            unassigned = "unbilled",
        )

        assertEquals(2.0, usage.getValue("person"), 0.001)
        assertEquals(5.0, usage.getValue("unbilled"), 0.001)
    }

    @Test fun `current reconciliation is idempotent and recomputes automatic cost`() {
        val first = LedgerReconciliation.reconcile(
            usageByPerson = mapOf("person" to 2.0),
            existing = emptyList(),
            defaultRate = 7_700,
            monthRate = 8_000,
            personRates = emptyMap(),
        )
        val second = LedgerReconciliation.reconcile(
            usageByPerson = mapOf("person" to 3.0),
            existing = first,
            defaultRate = 7_700,
            monthRate = 8_000,
            personRates = emptyMap(),
        )

        assertEquals(1, second.size)
        assertEquals(3.0, second.single().usageGb, 0.001)
        assertEquals(24_000, second.single().owedToman)
        assertEquals(8_000, second.single().rateUsed)
    }

    @Test fun `manual cost override wins while usage and effective rate stay current`() {
        val previous = ReconcileLine("person", 1.0, 7_700, 12_345, 12_345, false, 0, "", true)
        val result = LedgerReconciliation.reconcile(
            usageByPerson = mapOf("person" to 4.0),
            existing = listOf(previous),
            defaultRate = 7_700,
            monthRate = 8_000,
            personRates = mapOf("person" to 9_000),
        ).single()

        assertEquals(4.0, result.usageGb, 0.001)
        assertEquals(9_000, result.rateUsed)
        assertEquals(12_345, result.owedToman)
        assertEquals(12_345L, result.costOverride)
    }

    @Test fun `owed rounds to the nearest thousand like router bills`() {
        assertEquals(10_000, Pricing.owedToman(1.234, 7700))   // 9501.8 → 10000
        assertEquals(0, Pricing.owedToman(0.05, 7700))         // 385 → 0
        assertEquals(78_000, Pricing.owedToman(10.1, 7700))    // 77770 → 78000
        assertEquals(0, Pricing.owedToman(5.0, 0))
    }

    @Test fun `router import source tracking gives each source month a stable distinct row`() {
        assertEquals(
            "1405/05|__unassigned__@2026-08",
            RouterImportTracking.entryKey("1405/05", "2026-08"),
        )
        assertTrue(
            RouterImportTracking.entryKey("1405/05", "2026-08") !=
                RouterImportTracking.entryKey("1405/05", "2026-07"),
        )
        assertTrue(RouterImportTracking.isSourceSpecific("1405/05|__unassigned__@2026-08", "1405/05", "__unassigned__"))
        assertTrue(!RouterImportTracking.isSourceSpecific("1405/05|person", "1405/05", "person"))
    }

    // ── Attribution ──

    @Test fun `gregorian months attribute by the day the Jalali month is most represented by`() {
        // 2026-08-15 is in Mordad 1405 → August 2026 bills to 1405/05
        assertEquals(1405 to 5, MonthAttribution.attribution(2026, 8))
        // 2026-01-15 is in Dey 1404
        assertEquals(1404 to 10, MonthAttribution.attribution(2026, 1))
        // 2026-03-15 is before Nowruz → Esfand 1404
        assertEquals(1404 to 12, MonthAttribution.attribution(2026, 3))
        // 2026-04-15 is in Farvardin 1405
        assertEquals(1405 to 1, MonthAttribution.attribution(2026, 4))
    }

    @Test fun `month key pads the month`() {
        assertEquals("1405/05", MonthAttribution.key(1405, 5))
        assertEquals("1405/12", MonthAttribution.key(1405, 12))
    }

    // ── Summary ──

    @Test fun `summary totals and collection rate`() {
        val lines = listOf(
            LedgerLine(10.0, 77_000, 77_000),   // paid in full
            LedgerLine(5.0, 38_000, 10_000),    // partial
            LedgerLine(2.0, 15_000, 0),         // unpaid
        )
        val s = LedgerSummaryMath.summarize(lines)
        assertEquals(3, s.persons)
        assertEquals(17.0, s.usageGb, 0.001)
        assertEquals(130_000, s.owed)
        assertEquals(87_000, s.collected)
        assertEquals(43_000, s.unpaid)
        assertEquals(87_000f / 130_000f, s.collectionRate, 0.0001f)
    }

    @Test fun `summary collection rate is one when nothing is owed`() {
        val s = LedgerSummaryMath.summarize(listOf(LedgerLine(0.0, 0, 0)))
        assertEquals(1f, s.collectionRate, 0.0f)
    }

    // ── Read model ──

    @Test fun `read model derives every ledger surface from amounts`() {
        val model = LedgerReadModel(
            persons = listOf(
                LedgerReadPerson("p1", "Ali", "Family"),
                LedgerReadPerson("p2", "Sara", "Family"),
            ),
            months = listOf(
                LedgerReadMonth("1405/01", 1405, 1),
                LedgerReadMonth("1405/02", 1405, 2),
            ),
            entries = listOf(
                LedgerReadEntry("a", "1405/01", "p1", 2.0, 7_700, 20_000, 25_000, "overpaid", paid = false),
                LedgerReadEntry("b", "1405/01", "p2", 1.0, 7_700, 10_000, 4_000, "partial", paid = true),
                LedgerReadEntry("c", "1405/02", "p1", 3.0, 7_700, 30_000, 0, "unpaid", paid = true),
            ),
        )

        val month = model.month(
            "1405/01",
            LedgerMonthQuery(payment = LedgerPaymentFilter.ALL, sort = LedgerRowSort.UNPAID),
        )
        assertEquals(listOf("b", "a"), month.rows.map { it.key })
        assertEquals(LedgerPaymentStatus.PAID, month.rows[1].amounts.status)
        assertEquals(0, month.rows[1].amounts.unpaid)
        assertEquals(30_000, month.summary.owed)
        assertEquals(29_000, month.summary.collected)
        assertEquals(6_000, month.summary.unpaid)
        assertEquals(listOf("Family"), month.groups)

        val history = model.personHistory("p1")
        assertEquals(listOf("1405/02", "1405/01"), history.map { it.monthKey })
        assertEquals(LedgerPaymentStatus.UNPAID, history.first().amounts.status)

        val year = model.year(1405)
        assertEquals(30_000, year.months[0].owed)
        assertEquals(29_000, year.months[0].collection)
        assertEquals(6_000, year.months[0].unpaid)
        assertEquals(60_000, year.summary.owed)
        assertEquals(36_000, year.summary.unpaid)
        assertEquals(listOf("Ali", "Sara"), year.personTotals.map { it.name })
        assertEquals(60_000, year.groupTotals.single().amounts.owed)

        assertTrue(model.monthCsvRows("1405/01").first().contains("Ali"))
        assertTrue(model.monthCsv("1405/01").contains("20000,25000,0"))
        assertTrue(model.yearCsv(1405).trimEnd().lineSequence().last().contains("60000,29000,36000"))
    }

    @Test fun `local generated rows replace router fallback across all read projections`() {
        val model = LedgerReadModel(
            persons = listOf(
                LedgerReadPerson("person", "Ali"),
                LedgerReadPerson("__unassigned__", "Unbilled"),
            ),
            months = listOf(
                LedgerReadMonth("1405/01", 1405, 1),
                LedgerReadMonth("1405/02", 1405, 2),
            ),
            entries = listOf(
                LedgerReadEntry("1405/01|person", "1405/01", "person", 2.0, 7_700, 15_000, 5_000, "local"),
                LedgerReadEntry("1405/01|__unassigned__@2026-04", "1405/01", "__unassigned__", 9.0, 7_700, 69_000, 0, "import"),
                LedgerReadEntry("1405/02|__unassigned__@2026-05", "1405/02", "__unassigned__", 4.0, 7_700, 31_000, 0, "fallback"),
            ),
        )

        assertEquals(listOf("1405/01|person"), model.month("1405/01").rows.map { it.key })
        assertEquals(2.0, model.month("1405/01").summary.usageGb, 0.001)
        assertEquals(listOf("1405/02|__unassigned__@2026-05"), model.month("1405/02").rows.map { it.key })
        assertEquals(46_000, model.year(1405).summary.owed)
        assertEquals(1, model.monthCsvRows("1405/01").size)
        assertTrue(model.monthCsv("1405/01").contains("local"))
        assertTrue(!model.monthCsv("1405/01").contains("import"))
        assertTrue(model.yearCsv(1405).contains("fallback"))
        assertTrue(model.personHistory("__unassigned__").none { it.monthKey == "1405/01" })
    }

    // ── Suggestions ──

    private fun ctx(
        names: List<Pair<String, String>>,
        history: Map<String, List<String>> = emptyMap(),
        active: Map<String, String> = emptyMap(),
        ouiShare: Map<Pair<String, String>, Int> = emptyMap(),
        activity: Map<Pair<String, String>, Float> = emptyMap(),
    ) = SuggestionContext(
        persons = names,
        historyOfMac = { history[it] ?: emptyList() },
        activeOwner = { active[it] },
        ouiShareCount = { m, p -> ouiShare[m to p] ?: 0 },
        activityScore = { m, p -> activity[m to p] ?: 0f },
    )

    @Test fun `no signals - no suggestion`() {
        val c = ctx(listOf("p1" to "پارسا"))
        assertEquals(0, SuggestionScorer.score("aa:bb:cc:00:11:22", "router", c).size)
    }

    @Test fun `history is the strongest signal and survives soft unassignment`() {
        val c = ctx(
            names = listOf("p1" to "پارسا", "p2" to "زهرا"),
            history = mapOf("aa:bb:cc:00:11:22" to listOf("p1")),
        )
        val scored = SuggestionScorer.score("aa:bb:cc:00:11:22", "MiTV", c)
        assertEquals(1, scored.size)
        assertEquals("p1", scored[0].personId)
        assertTrue(SuggestionSignal.HISTORY in scored[0].signals)
    }

    @Test fun `name token match suggests the person named in the device`() {
        val c = ctx(names = listOf("p1" to "پارسا", "p2" to "زهرا"))
        val scored = SuggestionScorer.score("a1:b2:c3:00:00:01", "iPhone پارسا", c)
        assertEquals("p1", scored.firstOrNull()?.personId)
        assertTrue(SuggestionSignal.NAME in scored.first().signals)
    }

    @Test fun `oui batch - devices of the same person share a vendor prefix`() {
        val c = ctx(
            names = listOf("p1" to "پارسا"),
            ouiShare = mapOf("aa:bb:cc:00:11:22" to "p1" to 1),
        )
        val scored = SuggestionScorer.score("aa:bb:cc:00:11:22", "TV", c)
        assertEquals(1, scored.size)
        assertTrue(SuggestionSignal.OUI in scored[0].signals)
    }

    @Test fun `an owned device is never re-suggested to its owner`() {
        val c = ctx(
            names = listOf("p1" to "پارسا"),
            history = mapOf("aa:bb:cc:00:11:22" to listOf("p1")),
            active = mapOf("aa:bb:cc:00:11:22" to "p1"),
        )
        assertTrue(SuggestionScorer.score("aa:bb:cc:00:11:22", "iPhone", c).isEmpty())
    }

    @Test fun `oui prefix normalises separators and case`() {
        assertEquals("aa:bb:cc", SuggestionScorer.oui("AA:BB:CC:DD:EE:FF"))
        assertEquals("aa:bb:cc", SuggestionScorer.oui("aabbccddeeff"))
    }
}