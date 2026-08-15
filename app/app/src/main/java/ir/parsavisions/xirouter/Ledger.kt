package ir.parsavisions.xirouter

/**
 * The ledger's pure arithmetic: pricing, month attribution, summaries, and the
 * owner-suggestion scorer. No Android dependencies — the ViewModel supplies data,
 * this object decides. Tested at this seam by LedgerTest.
 */

// ── Pricing ───────────────────────────────────────────────────────────────────

object Pricing {
    /** The app-wide default price per GB in Toman when nothing else is set. */
    const val DEFAULT_RATE: Long = 7700

    /** The router rounds every bill to the nearest 1,000 Toman; the ledger follows. */
    const val ROUNDING: Long = 1000

    /** Effective flat rate: person override, then the frozen rate for a closed month, otherwise today's default. */
    fun resolveRate(default: Long, frozenMonthRate: Long?, personRate: Long? = null): Long =
        personRate ?: frozenMonthRate ?: default

    /** usage × rate, rounded the way the router's bills are. */
    fun owedToman(usageGb: Double, rate: Long): Long {
        if (usageGb <= 0.0 || rate <= 0) return 0
        val raw = usageGb * rate
        return Math.round(raw / ROUNDING.toDouble()) * ROUNDING
    }
}

// ── Router month → Jalali month attribution ──────────────────────────────────

object MonthAttribution {
    /**
     * Which Jalali month a router/Gregorian month's usage belongs to. Uses the Jalali
     * date of the 15th of the Gregorian month — the day the month is most representative
     * of — so a few boundary days always land in the neighbour's account.
     */
    fun attribution(year: Int, month: Int): Pair<Int, Int> {
        val jalali = jalaliOf(gregorianDay(year, month, 15))
        return jalali.year to jalali.month
    }

    /** monthKey "1405/05", the ledger's stable primary label. */
    fun key(jYear: Int, jMonth: Int): String = "$jYear/${jMonth.toString().padStart(2, '0')}"
}

// ── Month summary ─────────────────────────────────────────────────────────────

/** One ledger row, decoupled from the Room entity so the math is testable. */
data class LedgerLine(
    val usageGb: Double,
    val owed: Long,
    val paidToman: Long,
)

data class LedgerSummary(
    val persons: Int,
    val usageGb: Double,
    val owed: Long,
    val collected: Long,
    val unpaid: Long,
) {
    /** 0..1 — paid share of what was owed; 1 when nothing was owed. */
    val collectionRate: Float
        get() = if (owed > 0) (collected.toFloat() / owed).coerceIn(0f, 1f) else 1f
}

data class DailyUsageValue(val day: Long, val mac: String, val gb: Double)
data class OwnershipInterval(val mac: String, val personId: String, val sinceDay: Long, val untilDay: Long?)

object LedgerAggregation {
    fun usageByOwner(
        dailyUsage: List<DailyUsageValue>,
        ownership: List<OwnershipInterval>,
        visibleMacs: Set<String>,
        unassigned: String,
    ): Map<String, Double> = dailyUsage
        .filter { it.mac in visibleMacs }
        .map { row ->
            val owner = ownership
                .filter { it.mac == row.mac && row.day >= it.sinceDay && (it.untilDay == null || row.day < it.untilDay) }
                .maxByOrNull { it.sinceDay }
                ?.personId ?: unassigned
            owner to row.gb
        }
        .groupingBy { it.first }
        .fold(0.0) { total, (_, gb) -> total + gb }
}

/** Room-independent input/output for idempotent live and closed-month reconciliation. */
data class ReconcileLine(
    val personId: String,
    val usageGb: Double,
    val rateUsed: Long,
    val owedToman: Long,
    val costOverride: Long?,
    val paid: Boolean,
    val paidToman: Long,
    val note: String,
    val edited: Boolean,
)

object LedgerReconciliation {
    fun reconcile(
        usageByPerson: Map<String, Double>,
        existing: List<ReconcileLine>,
        defaultRate: Long,
        monthRate: Long?,
        personRates: Map<String, Long?>,
    ): List<ReconcileLine> {
        val old = existing.associateBy { it.personId }
        val generated = usageByPerson.filterValues { it > 0 }.map { (personId, gb) ->
            val previous = old[personId]
            val rate = Pricing.resolveRate(defaultRate, monthRate, personRates[personId])
            val computed = Pricing.owedToman(gb, rate)
            previous?.copy(
                usageGb = gb,
                rateUsed = rate,
                owedToman = previous.costOverride ?: computed,
            ) ?: ReconcileLine(personId, gb, rate, computed, null, false, 0, "", false)
        }
        val preservedStale = existing.filter {
            it.personId !in usageByPerson && (it.edited || it.paid || it.paidToman > 0 || it.costOverride != null || it.note.isNotBlank())
        }
        return generated + preservedStale
    }
}

object RouterImportTracking {
    /** A router source month owns one stable ledger row, so retries replace rather than add. */
    fun entryKey(monthKey: String, sourceMonth: String): String =
        "$monthKey|__unassigned__@$sourceMonth"

    fun isSourceSpecific(entryKey: String, monthKey: String, personId: String): Boolean =
        entryKey != "$monthKey|$personId"
}

object LedgerSummaryMath {
    fun summarize(lines: List<LedgerLine>): LedgerSummary {
        var usage = 0.0
        var owed = 0L
        var collected = 0L
        var unpaid = 0L
        for (line in lines) {
            usage += line.usageGb
            owed += line.owed
            collected += line.paidToman
            unpaid += (line.owed - line.paidToman).coerceAtLeast(0)
        }
        return LedgerSummary(lines.size, usage, owed, collected, unpaid)
    }
}

// ── Read model ────────────────────────────────────────────────────────────────

data class LedgerReadPerson(val id: String, val name: String, val group: String = "")
data class LedgerReadMonth(val key: String, val jYear: Int, val jMonth: Int)
data class LedgerReadEntry(
    val key: String,
    val monthKey: String,
    val personId: String,
    val usageGb: Double,
    val rate: Long,
    val owed: Long,
    val collection: Long,
    val note: String,
    @Suppress("unused") val paid: Boolean = false,
)

/** The single Room-to-read-model boundary shared by UI and export adapters. */
fun ledgerReadModel(
    persons: List<PersonEntity>,
    months: List<LedgerMonthEntity>,
    entries: List<LedgerEntryEntity>,
) = LedgerReadModel(
    persons.map { LedgerReadPerson(it.id, it.name, it.group) },
    months.map { LedgerReadMonth(it.key, it.jYear, it.jMonth) },
    entries.map { LedgerReadEntry(it.key, it.monthKey, it.personId, it.usageGb, it.rateUsed, it.owedToman, it.paidToman, it.note, it.paid) },
)

enum class LedgerPaymentStatus { PAID, PARTIAL, UNPAID }
enum class LedgerPaymentFilter { ALL, PAID, PARTIAL, UNPAID }
enum class LedgerRowSort { NAME, USAGE, OWED, UNPAID }

data class LedgerAmounts(
    val owed: Long,
    val collection: Long,
    val unpaid: Long = (owed - collection).coerceAtLeast(0),
) {
    val status: LedgerPaymentStatus get() = when {
        unpaid == 0L -> LedgerPaymentStatus.PAID
        collection > 0L -> LedgerPaymentStatus.PARTIAL
        else -> LedgerPaymentStatus.UNPAID
    }
}

data class LedgerMonthQuery(
    val query: String = "",
    val personId: String? = null,
    val group: String? = null,
    val payment: LedgerPaymentFilter = LedgerPaymentFilter.ALL,
    val hidePaid: Boolean = false,
    val hideUnbilled: Boolean = false,
    val sort: LedgerRowSort = LedgerRowSort.OWED,
)

data class LedgerReadRow(
    val key: String,
    val monthKey: String,
    val personId: String,
    val personName: String,
    val group: String,
    val usageGb: Double,
    val rate: Long,
    val amounts: LedgerAmounts,
    val note: String,
)

data class LedgerMonthProjection(
    val rows: List<LedgerReadRow>,
    val allRowCount: Int,
    val groups: List<String>,
    val summary: LedgerSummary,
)
data class LedgerNamedTotal(val id: String, val name: String, val amounts: LedgerAmounts)
data class LedgerYearProjection(
    val months: List<LedgerAmounts>,
    val summary: LedgerSummary,
    val personTotals: List<LedgerNamedTotal>,
    val groupTotals: List<LedgerNamedTotal>,
)

/** Android-free read-model interface for every Ledger reporting surface. */
class LedgerReadModel(
    persons: List<LedgerReadPerson>,
    private val months: List<LedgerReadMonth>,
    entries: List<LedgerReadEntry>,
) {
    private val people = persons.associateBy { it.id }
    private val rows = entries
        .groupBy { it.monthKey }
        .values
        .flatMap { monthEntries ->
            // Local generated rows are authoritative for a Jalali month. Router source rows are
            // retained in Room for provenance/retry, but are a read-only fallback for months with
            // no local projection at all.
            val hasLocalRows = monthEntries.any {
                !RouterImportTracking.isSourceSpecific(it.key, it.monthKey, it.personId)
            }
            if (hasLocalRows) monthEntries.filterNot {
                RouterImportTracking.isSourceSpecific(it.key, it.monthKey, it.personId)
            } else monthEntries
        }
        .map { entry ->
            val person = people[entry.personId]
            LedgerReadRow(
                entry.key, entry.monthKey, entry.personId, person?.name ?: entry.personId,
                person?.group.orEmpty(), entry.usageGb, entry.rate,
                LedgerAmounts(entry.owed, entry.collection), entry.note,
            )
        }

    fun month(key: String, query: LedgerMonthQuery = LedgerMonthQuery()): LedgerMonthProjection {
        val all = rows.filter { it.monthKey == key }
        val needle = query.query.trim()
        val filtered = all.filter { row ->
            (needle.isBlank() || listOf(row.personName, row.group, row.note).any { it.contains(needle, true) }) &&
                (query.personId == null || query.personId == row.personId) &&
                (query.group == null || query.group == row.group) &&
                (query.payment == LedgerPaymentFilter.ALL || row.amounts.status.name == query.payment.name) &&
                (!query.hidePaid || row.amounts.status != LedgerPaymentStatus.PAID) &&
                (!query.hideUnbilled || row.personId != "__unassigned__")
        }.let { result ->
            when (query.sort) {
                LedgerRowSort.NAME -> result.sortedBy { it.personName }
                LedgerRowSort.USAGE -> result.sortedByDescending { it.usageGb }
                LedgerRowSort.OWED -> result.sortedByDescending { it.amounts.owed }
                LedgerRowSort.UNPAID -> result.sortedByDescending { it.amounts.unpaid }
            }
        }
        return LedgerMonthProjection(
            filtered,
            all.size,
            all.map { it.group }.filter { it.isNotBlank() }.distinct().sorted(),
            summary(all),
        )
    }

    fun personHistory(personId: String): List<LedgerReadRow> =
        rows.filter { it.personId == personId }.sortedByDescending { it.monthKey }

    fun year(jYear: Int): LedgerYearProjection {
        val yearMonths = months.filter { it.jYear == jYear }
        val keys = yearMonths.map { it.key }.toSet()
        val yearRows = rows.filter { it.monthKey in keys }
        fun totals(grouped: Map<String, List<LedgerReadRow>>, name: (String) -> String) = grouped.map { (id, lines) ->
            LedgerNamedTotal(id, name(id), amounts(lines))
        }.sortedByDescending { it.amounts.owed }
        return LedgerYearProjection(
            months = (1..12).map { month -> amounts(yearRows.filter { row -> yearMonths.any { it.jMonth == month && it.key == row.monthKey } }) },
            summary = summary(yearRows),
            personTotals = totals(yearRows.groupBy { it.personId }) { people[it]?.name ?: it },
            groupTotals = totals(yearRows.groupBy { it.group.ifBlank { "بدون گروه" } }) { it },
        )
    }

    fun monthCsvRows(key: String): List<String> {
        val month = months.find { it.key == key } ?: return emptyList()
        return rows.filter { it.monthKey == key }.map { row ->
            "${month.key},${month.jYear},${month.jMonth},${csv(row.personName)},${row.usageGb},${row.rate}," +
                "${row.amounts.owed},${row.amounts.collection},${row.amounts.unpaid},${csv(row.note)}"
        }
    }

    fun monthCsv(key: String): String = csvText(
        "month,jalaliYear,jalaliMonth,person,usage_gb,rate,owed_toman,paid_toman,unpaid_toman,note",
        monthCsvRows(key),
    )

    fun yearCsvRows(jYear: Int): List<String> = rows.filter { row ->
        months.any { it.jYear == jYear && it.key == row.monthKey }
    }.map { row ->
        "$jYear,${row.monthKey.substringAfter("/")},${csv(row.personName)},${row.usageGb},${row.rate}," +
            "${row.amounts.owed},${row.amounts.collection},${row.amounts.unpaid},${csv(row.note)}"
    }

    fun yearCsv(jYear: Int): String {
        val yearRows = rows.filter { row -> months.any { it.jYear == jYear && it.key == row.monthKey } }
        val total = summary(yearRows)
        return csvText(
            "year,jalaliMonth,person,usage_gb,rate,owed_toman,paid_toman,unpaid_toman,note",
            yearCsvRows(jYear) + "TOTAL,,,${total.usageGb},,${total.owed},${total.collected},${total.unpaid},",
        )
    }

    private fun amounts(lines: List<LedgerReadRow>) = LedgerAmounts(
        lines.sumOf { it.amounts.owed },
        lines.sumOf { it.amounts.collection },
        lines.sumOf { it.amounts.unpaid },
    )

    private fun summary(lines: List<LedgerReadRow>) = LedgerSummaryMath.summarize(
        lines.map { LedgerLine(it.usageGb, it.amounts.owed, it.amounts.collection) },
    )

    private fun csv(value: String) = "\"${value.replace("\"", "'")}\""
    private fun csvText(header: String, lines: List<String>) = (listOf(header) + lines).joinToString("\n", postfix = "\n")
}

// ── Owner suggestion ──────────────────────────────────────────────────────────

/** Why a suggestion fired — shown to the user as one honest line. */
enum class SuggestionSignal { HISTORY, NAME, OUI, ACTIVITY }

data class OwnerSuggestion(
    val personId: String,
    val score: Double,
    val signals: Set<SuggestionSignal>,
)

/** The data the scorer needs, provided by the ViewModel from Room + router state. */
data class SuggestionContext(
    val persons: List<Pair<String, String>>,            // id -> display name
    val historyOfMac: (String) -> List<String>,         // every personId the MAC ever had
    val activeOwner: (String) -> String?,               // current ownerPersonId
    val ouiShareCount: (String, String) -> Int,         // (mac, personId) -> other devices of person sharing the MAC's OUI
    val activityScore: (String, String) -> Float,       // (mac, personId) -> 0..1 co-activity/volume similarity
)

object SuggestionScorer {
    private const val HISTORY_WEIGHT = 10.0
    private const val NAME_WEIGHT = 3.0
    private const val OUI_WEIGHT = 1.5
    private const val ACTIVITY_CAP = 4.0

    /** MAC vendor prefix "aa:bb:cc" — the first three octets. */
    fun oui(mac: String): String {
        val clean = mac.replace(":", "").lowercase().take(6)
        return clean.chunked(2).joinToString(":")
    }

    /** A device name matching a person token = "iPhone پارسا" vs person "پارسا". */
    fun nameTokenMatch(deviceName: String, personName: String): Boolean {
        val p = personName.trim()
        if (p.isEmpty()) return false
        val tokens = deviceName.split(Regex("[\\s_\\-./]+")).filter { it.isNotBlank() }
        return tokens.any { it == p || p.startsWith(it) && p.length >= it.length + 1 || it.startsWith(p) && it.length >= p.length + 1 }
    }

    fun score(mac: String, deviceName: String, ctx: SuggestionContext): List<OwnerSuggestion> {
        val out = mutableListOf<OwnerSuggestion>()
        ctx.persons.forEach { (personId, personName) ->
            if (ctx.activeOwner(mac) == personId) return@forEach   // already theirs
            var score = 0.0
            val signals = mutableSetOf<SuggestionSignal>()

            val history = ctx.historyOfMac(mac)
            if (personId in history) {
                score += HISTORY_WEIGHT
                signals += SuggestionSignal.HISTORY
            }
            if (nameTokenMatch(deviceName, personName)) {
                score += NAME_WEIGHT
                signals += SuggestionSignal.NAME
            }
            val ouiShare = ctx.ouiShareCount(mac, personId)
            if (ouiShare > 0) {
                score += OUI_WEIGHT * ouiShare
                signals += SuggestionSignal.OUI
            }
            val activity = ctx.activityScore(mac, personId)
            if (activity > 0.5f) {
                score += ACTIVITY_CAP * activity
                signals += SuggestionSignal.ACTIVITY
            }
            if (score > 0) out += OwnerSuggestion(personId, score, signals)
        }
        return out.sortedByDescending { it.score }
    }
}