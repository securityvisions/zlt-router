package ir.parsavisions.xirouter

import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.jsonObject

// ── v2 pure domain seams (ADR-0001…0011). Tested at these seams only: the
// keepers/DAOs are thin adapters; the decision math lives here.

// ── Payments + person credit (ADR-0001) ──────────────────────────────────────

enum class BillStatus { UNPAID, PARTIAL, PAID, OVERPAID }

object PaymentMath {
    /** A bill's total from the ledger entry: explicit override, else usage×rate. */
    fun billTotal(entry: LedgerEntryEntity): Long =
        entry.costOverride ?: Pricing.owedToman(entry.usageGb, entry.rateUsed)

    /** Payments visible to a bill (person+month). */
    fun totalPaid(payments: List<PaymentEntity>): Long = payments.sumOf { it.amountToman }

    /** Status of one bill given its payments and the person's standing credit. */
    fun billStatus(owed: Long, payments: List<PaymentEntity>, creditToman: Long): BillStatus {
        if (owed <= 0) return if (totalPaid(payments) + creditToman > 0) BillStatus.OVERPAID else BillStatus.PAID
        val paid = totalPaid(payments) + creditToman
        return when {
            paid > owed -> BillStatus.OVERPAID
            paid >= owed -> BillStatus.PAID
            paid > 0 -> BillStatus.PARTIAL
            else -> BillStatus.UNPAID
        }
    }

    /** Excess payments over a bill -> the person's credit (money is never lost). */
    fun excessToCredit(owed: Long, payments: List<PaymentEntity>): Long =
        (totalPaid(payments) - owed).coerceAtLeast(0)

    /** Apply a person's credit oldest-unpaid-first across their bills. */
    fun applyCreditToBills(credit: Long, bills: List<Pair<String, Long>>): Map<String, Long> {
        var remaining = credit
        val applied = mutableMapOf<String, Long>()
        bills.sortedBy { it.first }.forEach { (monthKey, owed) ->
            if (remaining <= 0) return@forEach
            val take = minOf(remaining, owed.coerceAtLeast(0))
            applied[monthKey] = take
            remaining -= take
        }
        return applied
    }
}

// ── Quotas + crossing events (ADR-0003) ──────────────────────────────────────

object QuotaCrossing {
    const val NONE = "none"
    const val WARN = "warn"
    const val CRITICAL = "critical"

    /** Current quota level for a person, given usage and thresholds. */
    fun level(usedGb: Double, quotaGb: Double?, warnPct: Int, critPct: Int): String {
        if (quotaGb == null || quotaGb <= 0) return NONE
        val pct = usedGb / quotaGb * 100
        return when {
            pct >= critPct -> CRITICAL
            pct >= warnPct -> WARN
            else -> NONE
        }
    }

    /** Crossings vs the previous level: emits only NEW escalations (warn, critical). */
    fun crossings(prevLevel: String, currentLevel: String): List<String> {
        val out = mutableListOf<String>()
        if (currentLevel == WARN && prevLevel == NONE) out += "quota_warn_crossed"
        if (currentLevel == CRITICAL && prevLevel != CRITICAL) out += "quota_critical_crossed"
        return out
    }
}

// ── Inbox / timeline / audit event models (ADR-0004/0005) ───────────────────

object Events {
    /** Stable-ish event id: kind + millis + a monotonic suffix. */
    fun id(prefix: String, atMillis: Long): String = "$prefix-$atMillis"
}

// ── Device enrichment (ADR-0009) ─────────────────────────────────────────────

object Enrichment {
    /** Poll update: an online client refreshes ip + lastSeen; offline leaves them. */
    fun apply(current: DeviceSettingsEntity, ip: String?, online: Boolean, nowMillis: Long): DeviceSettingsEntity =
        if (online) {
            current.copy(ip = ip?.takeIf { it.isNotBlank() } ?: current.ip, lastSeenUnix = nowMillis)
        } else {
            current
        }
}

// ── Saved-view search (ADR-0007) ─────────────────────────────────────────────

object Search {
    /** Case-insensitive substring match across any of the fields. */
    fun matches(query: String, fields: List<String>): Boolean {
        val q = query.trim().lowercase()
        if (q.isEmpty()) return true
        return fields.any { it.lowercase().contains(q) }
    }
}

// ── Backup/restore codec (ADR-0008) ──────────────────────────────────────────

object BackupCodec {
    const val VERSION = 1
    private const val SECRET_KEYS = "token,pin,lastsnapshot,last_snapshot"

    @Serializable
    data class Envelope(val schemaVersion: Int, val exportedAt: Long, val domain: JsonObject)

    /** Strip sensitive keys from a domain map before it leaves the app. */
    fun sanitize(domain: JsonObject): JsonObject {
        val allowed = domain.filterKeys { it.lowercase() !in SECRET_KEYS.split(",") }
        return JsonObject(allowed)
    }

    fun encode(json: Json, domain: JsonObject, exportedAt: Long): String =
        json.encodeToString(Envelope(VERSION, exportedAt, sanitize(domain)))

    /** null on invalid JSON or an unsupported version (never restore unknown). */
    fun decode(json: Json, raw: String): Envelope? = runCatching {
        val envelope = json.decodeFromString<Envelope>(raw)
        if (envelope.schemaVersion != VERSION) null else envelope
    }.getOrNull()
}

// ── Automation engine (ADR-0002) ─────────────────────────────────────────────

@Serializable
data class ConditionEnvelope(val type: String, val params: JsonObject = JsonObject(emptyMap()))

@Serializable
data class ActionEnvelope(val type: String, val params: JsonObject = JsonObject(emptyMap()))

@Serializable
data class AutomationRuleCodec(
    val version: Int = 1,
    val name: String,
    val condition: ConditionEnvelope,
    val action: ActionEnvelope,
)

/** Everything a rule may look at on one evaluation. */
data class AutomationContext(
    val packageRemainPct: Double? = null,
    val quotaUsedPct: Double? = null,
    val proxyUp: Boolean = true,
    val unpaidPeople: Int = 0,
    val offlineDevices: Int = 0,
)

object AutomationEngine {
    fun param(params: JsonObject, key: String, default: Double): Double =
        (params[key] as? JsonPrimitive)?.content?.toDoubleOrNull() ?: default

    fun param(params: JsonObject, key: String, default: Long): Long =
        (params[key] as? JsonPrimitive)?.content?.toLongOrNull() ?: default

    /** True when the condition currently holds. Unknown subtypes never fire. */
    fun evaluate(condition: ConditionEnvelope, ctx: AutomationContext): Boolean = when (condition.type) {
        "package_below" -> ctx.packageRemainPct?.let { it < param(condition.params, "pct", 15.0) } ?: false
        "quota_above" -> ctx.quotaUsedPct?.let { it > param(condition.params, "pct", 80.0) } ?: false
        "proxy_down" -> !ctx.proxyUp
        "unpaid_above" -> ctx.unpaidPeople >= param(condition.params, "count", 0L)
        "offline_above" -> ctx.offlineDevices >= param(condition.params, "count", 0L)
        else -> false
    }

    /** Fire only on the rising edge (false→true), so a rule never re-fires while true. */
    fun shouldFire(prevFired: Boolean, fires: Boolean): Boolean = fires && !prevFired

    fun encode(json: Json, rule: AutomationRuleCodec): String = json.encodeToString(rule)

    fun decode(json: Json, raw: String): AutomationRuleCodec? =
        runCatching { json.decodeFromString<AutomationRuleCodec>(raw) }.getOrNull()
}

// ── Messaging (ADR-0011) ─────────────────────────────────────────────────────

object MessageCenter {
    /** Render {placeholders}; a missing variable becomes an empty string. */
    fun render(template: String, vars: Map<String, String>): String {
        var out = template
        val names = Regex("\\{([a-z_]+)\\}").findAll(template).map { it.groupValues[1] }.toList()
        names.forEach { name -> out = out.replace("{$name}", vars[name].orEmpty()) }
        return out
    }
}

// ── Forecasting + insights (ADR-0010) ────────────────────────────────────────

object Forecasting {
    /** Linear run-rate month-end projection; 0 when nothing to extrapolate. */
    fun projectUsage(usedGb: Double, daysElapsed: Int, daysInMonth: Int): Double =
        if (daysElapsed > 0 && usedGb > 0) usedGb * daysInMonth / daysElapsed else 0.0

    fun projectCost(projectedGb: Double, rateToman: Long): Long = (projectedGb * rateToman).toLong()

    /** Days until a package is exhausted at the current drain; null when no drain. */
    fun packageExhaustionDays(remainGb: Double, drainGbPerDay: Double): Int? =
        if (drainGbPerDay > 0) (remainGb / drainGbPerDay).toInt() else null
}

object Insights {
    /**
     * The five stable insight rules. Each returns a Persian-first phrase or
     * null when the inputs can't support it. Callers label output as «برآورد».
     */
    fun generate(
        usageTodayGb: Double, prevMonthTotalGb: Double?, topPersonGb: Double?,
        packageExhaustionDays: Int?, spendTodayToman: Long, avgSpendToman: Long,
        newDeviceCount: Int,
    ): List<String> {
        val out = mutableListOf<String>()
        if (prevMonthTotalGb != null && prevMonthTotalGb > 0) {
            val diff = usageTodayGb - prevMonthTotalGb / 30
            out += if (diff > 0) "مصرف امروز بالاتر از میانگین ماه قبل است" else "مصرف امروز پایینتر از میانگین ماه قبل است"
        }
        if (topPersonGb != null) out += "بیشترین مصرف امروز: $topPersonGb گیگابایت"
        if (packageExhaustionDays != null) out += if (packageExhaustionDays <= 3) "پکیج در کمتر از ۳ روز تمام میشود" else "پکیج تا $packageExhaustionDays روز دیگر کافی است"
        if (spendTodayToman > 0 && avgSpendToman > 0) {
            out += if (spendTodayToman > avgSpendToman) "مخارج امروز بالاتر از میانگین است" else "مخارج امروز در حد میانگین است"
        }
        if (newDeviceCount > 0) out += "$newDeviceCount دستگاه جدید دیده شد"
        return out
    }
}
