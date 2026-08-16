package ir.parsavisions.xirouter

import kotlinx.serialization.json.Json
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.put
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class PaymentMathTest {
    private val json = Json { ignoreUnknownKeys = true }
    private fun payment(amount: Long) = PaymentEntity("p$amount", "person", "1405/05", amount, 1000L)

    @Test fun noPaymentsIsUnpaid() {
        assertEquals(BillStatus.UNPAID, PaymentMath.billStatus(77_000, emptyList(), 0))
    }

    @Test fun partialPaymentIsPartial() {
        assertEquals(BillStatus.PARTIAL, PaymentMath.billStatus(77_000, listOf(payment(50_000)), 0))
    }

    @Test fun fullPaymentIsPaid() {
        assertEquals(BillStatus.PAID, PaymentMath.billStatus(77_000, listOf(payment(77_000)), 0))
    }

    @Test fun overpaymentIsOverpaidAndExcessBecomesCredit() {
        val payments = listOf(payment(80_000))
        assertEquals(BillStatus.OVERPAID, PaymentMath.billStatus(77_000, payments, 0))
        assertEquals(3_000, PaymentMath.excessToCredit(77_000, payments))
    }

    @Test fun standingCreditCompletesAPartialBill() {
        assertEquals(BillStatus.PAID, PaymentMath.billStatus(77_000, listOf(payment(50_000)), 27_000))
        assertEquals(BillStatus.OVERPAID, PaymentMath.billStatus(77_000, listOf(payment(50_000)), 30_000))
    }

    @Test fun creditAppliesOldestUnpaidFirst() {
        val bills = listOf("1405/03" to 30_000L, "1405/04" to 50_000L, "1405/05" to 70_000L)
        val applied = PaymentMath.applyCreditToBills(90_000, bills)
        assertEquals(30_000, applied.getValue("1405/03"))
        assertEquals(50_000, applied.getValue("1405/04"))
        assertEquals(10_000, applied.getValue("1405/05"))
    }

    @Test fun creditDoesNotExceedTheBills() {
        val applied = PaymentMath.applyCreditToBills(500_000, listOf("1405/05" to 70_000L))
        assertEquals(70_000, applied.getValue("1405/05"))
    }

    @Test fun billTotalUsesOverrideWhenPresent() {
        val entry = LedgerEntryEntity("e", "1405/05", "person", usageGb = 10.0, rateUsed = 7_700, costOverride = 99_000)
        assertEquals(99_000, PaymentMath.billTotal(entry))
        val plain = LedgerEntryEntity("e2", "1405/05", "person", usageGb = 10.0, rateUsed = 7_700)
        assertEquals(77_000, PaymentMath.billTotal(plain))
    }

    @Test fun automationEnvelopeRoundTrips() {
        val rule = AutomationRuleCodec(
            name = "پایین آمدن پکیج",
            condition = ConditionEnvelope("package_below", buildJsonObject { put("pct", 15) }),
            action = ActionEnvelope("notify_inbox"),
        )
        val raw = AutomationEngine.encode(json, rule)
        val decoded = AutomationEngine.decode(json, raw)
        assertEquals(rule, decoded)
    }
}

class QuotaCrossingTest {
    @Test fun noQuotaMeansNoLevel() {
        assertEquals("none", QuotaCrossing.level(50.0, null, 70, 90))
    }

    @Test fun levelsEscalate() {
        assertEquals("none", QuotaCrossing.level(10.0, 100.0, 70, 90))
        assertEquals("warn", QuotaCrossing.level(75.0, 100.0, 70, 90))
        assertEquals("critical", QuotaCrossing.level(95.0, 100.0, 70, 90))
    }

    @Test fun crossingsEmitOnlyNewEscalations() {
        assertEquals(listOf("quota_warn_crossed"), QuotaCrossing.crossings("none", "warn"))
        assertEquals(listOf("quota_critical_crossed"), QuotaCrossing.crossings("warn", "critical"))
        assertEquals(emptyList<String>(), QuotaCrossing.crossings("none", "none"))
        assertEquals(emptyList<String>(), QuotaCrossing.crossings("critical", "critical"))
        assertEquals(emptyList<String>(), QuotaCrossing.crossings("critical", "warn")) // de-escalation: no event
    }
}

class AutomationEngineTest {
    private val ctx = AutomationContext(packageRemainPct = 12.0, quotaUsedPct = 85.0, proxyUp = false, unpaidPeople = 3, offlineDevices = 1)

    private fun cond(type: String, key: String, value: Number) =
        ConditionEnvelope(type, buildJsonObject { put(key, value.toString()) })

    @Test fun packageBelowFiresOnTheCrossing() {
        assertTrue(AutomationEngine.evaluate(cond("package_below", "pct", 15), ctx))
        assertFalse(AutomationEngine.evaluate(cond("package_below", "pct", 5), ctx))
    }

    @Test fun quotaAboveFires() {
        assertTrue(AutomationEngine.evaluate(cond("quota_above", "pct", 80), ctx))
        assertFalse(AutomationEngine.evaluate(cond("quota_above", "pct", 90), ctx))
    }

    @Test fun proxyDownFires() {
        assertTrue(AutomationEngine.evaluate(ConditionEnvelope("proxy_down"), ctx))
        assertFalse(AutomationEngine.evaluate(ConditionEnvelope("proxy_down"), ctx.copy(proxyUp = true)))
    }

    @Test fun unpaidAndOfflineCounts() {
        assertTrue(AutomationEngine.evaluate(cond("unpaid_above", "count", 2), ctx))
        assertFalse(AutomationEngine.evaluate(cond("unpaid_above", "count", 5), ctx))
        assertTrue(AutomationEngine.evaluate(cond("offline_above", "count", 1), ctx))
    }

    @Test fun unknownSubtypeNeverFires() {
        assertFalse(AutomationEngine.evaluate(ConditionEnvelope("future_condition"), ctx))
    }

    @Test fun shouldFireOnlyOnTheRisingEdge() {
        assertTrue(AutomationEngine.shouldFire(prevFired = false, fires = true))
        assertFalse(AutomationEngine.shouldFire(prevFired = true, fires = true))
        assertFalse(AutomationEngine.shouldFire(prevFired = true, fires = false))
        assertFalse(AutomationEngine.shouldFire(prevFired = false, fires = false))
    }
}

class MessageCenterTest {
    @Test fun rendersPlaceholders() {
        val out = MessageCenter.render(
            "سلام {name}؛ مصرف {usage} گیگابایت، مبلغ {amount} تومان.",
            mapOf("name" to "پارسا", "usage" to "12.5", "amount" to "96,000"),
        )
        assertEquals("سلام پارسا؛ مصرف 12.5 گیگابایت، مبلغ 96,000 تومان.", out)
    }

    @Test fun missingVariableBecomesEmpty() {
        assertEquals("سلام ؛ مصرف .", MessageCenter.render("سلام {name}؛ مصرف {usage}.", mapOf("nope" to "x")))
    }

    @Test fun missingTokensAreConsumedNotLeftLittered() {
        // A token that isn't in the variable map renders as empty (never literal braces).
        assertEquals("x  y", MessageCenter.render("x {braces} y", emptyMap()))
    }
}

class ForecastingTest {
    @Test fun linearRunRate() {
        assertEquals(30.0, Forecasting.projectUsage(10.0, 10, 30), 0.001)
    }

    @Test fun nothingToExtrapolate() {
        assertEquals(0.0, Forecasting.projectUsage(0.0, 10, 30), 0.001)
        assertEquals(0.0, Forecasting.projectUsage(10.0, 0, 30), 0.001)
    }

    @Test fun costAndExhaustion() {
        assertEquals(231_000, Forecasting.projectCost(30.0, 7_700))
        assertEquals(7, Forecasting.packageExhaustionDays(70.0, 10.0))
        assertNull(Forecasting.packageExhaustionDays(70.0, 0.0))
    }
}

class InsightsTest {
    @Test fun fiveRulesProduceStablePhrases() {
        val out = Insights.generate(
            usageTodayGb = 5.0, prevMonthTotalGb = 90.0, topPersonGb = 3.2,
            packageExhaustionDays = 2, spendTodayToman = 20_000, avgSpendToman = 15_000,
            newDeviceCount = 1,
        )
        assertTrue(out.isNotEmpty())
        assertTrue(out.any { it.contains("بالاتر از میانگین ماه قبل") })
        assertTrue(out.any { it.contains("بیشترین مصرف") })
        assertTrue(out.any { it.contains("کمتر از ۳ روز") })
        assertTrue(out.any { it.contains("بالاتر از میانگین است") })
        assertTrue(out.any { it.contains("دستگاه جدید") })
    }

    @Test fun noInputsNoInsights() {
        assertEquals(emptyList<String>(), Insights.generate(0.0, null, null, null, 0, 0, 0))
    }
}

class BackupCodecTest {
    private val json = Json { ignoreUnknownKeys = true }

    @Test fun envelopeRoundTrips() {
        val domain = buildJsonObject { put("persons", "[]"); put("payments", "[]") }
        val raw = BackupCodec.encode(json, domain, 1234L)
        val decoded = BackupCodec.decode(json, raw)
        assertEquals(BackupCodec.VERSION, decoded?.schemaVersion)
        assertEquals(1234L, decoded?.exportedAt)
    }

    @Test fun sensitiveKeysAreDropped() {
        val domain = buildJsonObject {
            put("token", "secret"); put("pin", "1234"); put("lastSnapshot", "x"); put("persons", "[]")
        }
        val raw = BackupCodec.encode(json, domain, 1L)
        val decoded = BackupCodec.decode(json, raw)
        val keys = decoded?.domain?.keys.orEmpty()
        assertFalse(keys.contains("token"))
        assertFalse(keys.contains("pin"))
        assertFalse(keys.contains("lastSnapshot"))
        assertTrue(keys.contains("persons"))
    }

    @Test fun unknownVersionIsRejected() {
        val raw = """{"schemaVersion":99,"exportedAt":1,"domain":{}}"""
        assertNull(BackupCodec.decode(json, raw))
    }

    @Test fun garbageIsRejected() {
        assertNull(BackupCodec.decode(json, "not json at all"))
    }
}

class SearchAndEnrichmentTest {
    @Test fun searchMatchesCaseInsensitiveAcrossFields() {
        assertTrue(Search.matches("iphone", listOf("iPhone پارسا", "aa:bb:cc")))
        assertTrue(Search.matches("AA:BB", listOf("iPhone", "aa:bb:cc:dd")))
        assertFalse(Search.matches("samsung", listOf("iPhone", "aa:bb")))
        assertTrue(Search.matches("", listOf("anything")))
    }

    @Test fun enrichmentUpdatesIpAndLastSeenWhenOnline() {
        val base = DeviceSettingsEntity("aa:bb:cc:dd:ee:ff")
        val updated = Enrichment.apply(base, "192.168.1.50", online = true, nowMillis = 999)
        assertEquals("192.168.1.50", updated.ip)
        assertEquals(999L, updated.lastSeenUnix)
    }

    @Test fun enrichmentLeavesOfflineDevicesAlone() {
        val base = DeviceSettingsEntity("aa:bb:cc:dd:ee:ff", ip = "192.168.1.50", lastSeenUnix = 100)
        val updated = Enrichment.apply(base, "192.168.1.60", online = false, nowMillis = 999)
        assertEquals("192.168.1.50", updated.ip)
        assertEquals(100L, updated.lastSeenUnix)
    }
}
