package ir.parsavisions.xirouter

import androidx.room.withTransaction
import java.util.Calendar
import java.util.TimeZone

/**
 * The ledger's plumbing shared by the ViewModel and the background worker:
 * device registry sync, the per-day recorder, month finalization, and the
 * one-time router-history import. Everything here is idempotent.
 */
sealed interface BulkValue<out T> {
    data object Keep : BulkValue<Nothing>
    data class Set<T>(val value: T) : BulkValue<T>
}

data class BulkDeviceChange(
    val macs: Set<String>,
    val ownerPersonId: BulkValue<String?> = BulkValue.Keep,
    val category: String? = null,
    val watched: Boolean? = null,
    val hideFromLedger: Boolean? = null,
)

object LedgerKeeper {

    private const val UNASSIGNED = "__unassigned__"

    /** Refresh the local device registry from the router's /devices answer. */
    suspend fun syncDevices(db: AppDb, r: DevicesResponse, usageToday: UsageResponse?) {
        r.devices.forEach { d ->
            val existing = db.deviceDao().byMac(d.mac)
            db.deviceDao().upsert(
                existing?.copy(
                    lastSeenName = d.name,
                    watched = d.watched,
                    alias = existing.alias.ifBlank { d.name },
                ) ?: DeviceSettingsEntity(
                    mac = d.mac, alias = d.name, lastSeenName = d.name, watched = d.watched,
                ),
            )
        }
        usageToday?.rows?.forEach { r ->
            if (db.deviceDao().byMac(r.mac) == null) {
                db.deviceDao().upsert(DeviceSettingsEntity(mac = r.mac, alias = r.name, lastSeenName = r.name))
            }
        }
    }

    /** Register unseen devices and store each device's maximum total for the Tehran day. */
    suspend fun recordDaily(db: AppDb, u: UsageResponse) {
        if (u.rows.isEmpty()) return
        val day = tehranDay(System.currentTimeMillis())
        db.withTransaction {
            val existing = db.ledgerDao().daysBetween(day, day).associateBy { it.mac }
            u.rows.forEach { row ->
                if (db.deviceDao().byMac(row.mac) == null) {
                    db.deviceDao().upsert(DeviceSettingsEntity(mac = row.mac, alias = row.name, lastSeenName = row.name))
                }
                val previous = existing[row.mac]?.gb ?: 0.0
                if (row.gb > 0 && row.gb >= previous) {
                    db.ledgerDao().upsertDaily(DailyUsageEntity("$day|${row.mac}", day, row.mac, row.gb))
                }
            }
        }
    }

    /** Ensure the current month exists; close the previous month once the month turns. */
    suspend fun ensureMonthly(db: AppDb, store: Store) = db.withTransaction {
        val today = tehranDay(System.currentTimeMillis())
        val here = jalaliOf(today)
        val currentKey = MonthAttribution.key(here.year, here.month)
        val known = db.ledgerDao().allMonths().associateBy { it.key }

        val current = known[currentKey] ?: LedgerMonthEntity(
            key = currentKey, jYear = here.year, jMonth = here.month,
            globalRate = store.defaultRate,
        ).also { db.ledgerDao().upsertMonth(it) }
        reconcileMonthInTransaction(db, store, current, jalaliMonthStart(today), today)

        val prevStart = jalaliMonthsBack(jalaliMonthStart(today), 1)
        val prevJ = jalaliOf(prevStart)
        val prevMonth = db.ledgerDao().month(MonthAttribution.key(prevJ.year, prevJ.month))
        if (prevMonth != null && prevMonth.closedDay == null) {
            finalizeMonthInTransaction(db, store, prevMonth, prevStart, jalaliMonthStart(today) - 1)
        }
    }

    /** Re-project a month from daily usage using the ownership interval valid on each day. */
    suspend fun reconcileMonth(db: AppDb, store: Store, month: LedgerMonthEntity, fromDay: Long, toDay: Long) =
        db.withTransaction { reconcileMonthInTransaction(db, store, month, fromDay, toDay) }

    private suspend fun reconcileMonthInTransaction(
        db: AppDb, store: Store, month: LedgerMonthEntity, fromDay: Long, toDay: Long,
    ) {
        ensureUnassigned(db)
        val visibleMacs = db.deviceDao().all().filterNot { it.hideFromLedger }.mapTo(mutableSetOf()) { it.mac }
        val ownership = db.ownershipDao().all().map { OwnershipInterval(it.mac, it.personId, it.sinceDay, it.untilDay) }
        val usage = LedgerAggregation.usageByOwner(
            db.ledgerDao().daysBetween(fromDay, toDay).map { DailyUsageValue(it.day, it.mac, it.gb) },
            ownership, visibleMacs, UNASSIGNED,
        )
        val existingEntities = db.ledgerDao().entries(month.key)
        // Source-specific import rows have their own identity and totals. Local daily reconciliation
        // must neither associate them by personId nor delete them as stale generated rows.
        val localEntities = existingEntities.filterNot { RouterImportTracking.isSourceSpecific(it.key, it.monthKey, it.personId) }
        val reconciled = LedgerReconciliation.reconcile(
            usage,
            localEntities.map { it.toReconcileLine() },
            store.defaultRate,
            month.globalRate.takeIf { month.closedDay != null },
            db.personDao().all().associate { it.id to it.rateOverride },
        )
        reconciled.forEach { line -> db.ledgerDao().upsertEntry(line.toEntity(month.key)) }
        val keep = reconciled.mapTo(mutableSetOf()) { it.personId }
        localEntities.filter { it.personId !in keep }.forEach { db.ledgerDao().deleteEntry(it.key) }
    }

    /** Freeze today's global default, reconcile with it, and mark a completed month closed atomically. */
    suspend fun finalizeMonth(db: AppDb, store: Store, month: LedgerMonthEntity, fromDay: Long, toDay: Long) =
        db.withTransaction { finalizeMonthInTransaction(db, store, month, fromDay, toDay) }

    private suspend fun finalizeMonthInTransaction(
        db: AppDb, store: Store, month: LedgerMonthEntity, fromDay: Long, toDay: Long,
    ) {
        val frozen = month.copy(globalRate = store.defaultRate, closedDay = toDay + 1)
        db.ledgerDao().upsertMonth(frozen)
        reconcileMonthInTransaction(db, store, frozen, fromDay, toDay)
    }

    suspend fun setDeviceOwner(db: AppDb, store: Store, mac: String, personId: String?, today: Long) =
        assignOwners(db, store, mapOf(mac to personId), today, "owner")

    /** Heterogeneous suggestion assignments are one atomic mutation, audit, and reconciliation. */
    suspend fun assignOwners(db: AppDb, store: Store, assignments: Map<String, String?>, today: Long, auditKind: String = "suggestions") =
        db.withTransaction {
            assignments.toSortedMap().forEach { (mac, personId) ->
                val device = db.deviceDao().byMac(mac) ?: DeviceSettingsEntity(mac)
                if (personId != device.ownerPersonId) {
                    db.ownershipDao().closeAll(mac, today)
                    personId?.let { db.ownershipDao().upsert(OwnershipHistoryEntity("$mac|$it|$today", mac, it, today)) }
                    db.deviceDao().upsert(device.copy(ownerPersonId = personId))
                }
            }
            db.ownershipAuditDao().insert(OwnershipAuditEntity(java.util.UUID.randomUUID().toString(), auditKind, today,
                details = assignments.toSortedMap().entries.joinToString(";") { "${it.key}=${it.value}" }))
            reconcileCurrentMonth(db, store, today)
        }

    /** One transaction, one effective Tehran day, one reconciliation for any bulk workspace action. */
    suspend fun bulkDevices(db: AppDb, store: Store, change: BulkDeviceChange, today: Long) =
        db.withTransaction {
            change.macs.distinct().forEach { mac ->
                val device = db.deviceDao().byMac(mac) ?: DeviceSettingsEntity(mac)
                var updated = device
                when (val owner = change.ownerPersonId) {
                    BulkValue.Keep -> Unit
                    is BulkValue.Set -> if (owner.value != device.ownerPersonId) {
                        db.ownershipDao().closeAll(mac, today)
                        owner.value?.let { db.ownershipDao().upsert(OwnershipHistoryEntity("$mac|$it|$today", mac, it, today)) }
                        updated = updated.copy(ownerPersonId = owner.value)
                    }
                }
                change.category?.let { updated = updated.copy(category = it.trim()) }
                change.watched?.let { updated = updated.copy(watched = it) }
                change.hideFromLedger?.let { updated = updated.copy(hideFromLedger = it) }
                db.deviceDao().upsert(updated)
            }
            db.ownershipAuditDao().insert(OwnershipAuditEntity(
                id = java.util.UUID.randomUUID().toString(), kind = "bulk", effectiveDay = today,
                details = "macs=${change.macs.sorted().joinToString(",")};owner=${change.ownerPersonId}",
            ))
            reconcileCurrentMonth(db, store, today)
        }

    suspend fun restorePerson(db: AppDb, personId: String, today: Long) = db.withTransaction {
        db.personDao().restore(personId)
        db.ownershipAuditDao().insert(OwnershipAuditEntity(java.util.UUID.randomUUID().toString(), "restore", today, details = "person=$personId"))
    }

    suspend fun archivePerson(db: AppDb, store: Store, personId: String, today: Long) =
        db.withTransaction {
            db.ownershipDao().all()
                .filter { it.personId == personId && it.untilDay == null }
                .forEach { db.ownershipDao().closeActive(it.mac, personId, today) }
            db.deviceDao().byOwner(personId).forEach { device ->
                db.deviceDao().upsert(device.copy(ownerPersonId = null))
            }
            db.personDao().archive(personId)
            reconcileCurrentMonth(db, store, today)
        }

    suspend fun applyOwnershipCorrection(
        db: AppDb, store: Store, request: OwnershipCorrectionRequest, today: Long,
    ): OwnershipCorrectionPlan = db.withTransaction {
        val existing = db.ownershipDao().forMac(request.mac)
        val usageDays = db.ledgerDao().daysBetween(request.startDay, request.endDay?.minus(1) ?: today).map { it.day }
        val plan = OwnershipPlanning.correction(request, existing.map { OwnershipRange(it.mac, it.personId, it.sinceDay, it.untilDay) }, usageDays, today)
        require(plan.valid) { "Invalid ownership interval" }
        // Correction is an explicit replacement, not an append: trim/split every conflicting interval.
        existing.filter { range -> plan.conflicts.any { it.range == OwnershipRange(range.mac, range.personId, range.sinceDay, range.untilDay) } }.forEach { range ->
            db.ownershipDao().delete(range.key)
            if (range.sinceDay < request.startDay)
                db.ownershipDao().upsert(range.copy(key = "${range.mac}|${range.personId}|${range.sinceDay}", untilDay = request.startDay))
            val requestEnd = request.endDay
            if (requestEnd != null && (range.untilDay == null || range.untilDay > requestEnd))
                db.ownershipDao().upsert(range.copy(key = "${range.mac}|${range.personId}|$requestEnd", sinceDay = requestEnd))
        }
        db.ownershipDao().upsert(OwnershipHistoryEntity("${request.mac}|${request.personId}|${request.startDay}", request.mac, request.personId, request.startDay, request.endDay))
        if (request.endDay == null || request.endDay > today) {
            val device = db.deviceDao().byMac(request.mac) ?: DeviceSettingsEntity(request.mac)
            db.deviceDao().upsert(device.copy(ownerPersonId = request.personId))
        }
        reconcileAffectedMonths(db, store, plan.affectedMonthKeys, today)
        db.ownershipAuditDao().insert(OwnershipAuditEntity(java.util.UUID.randomUUID().toString(), "correction", request.startDay, details = request.toString()))
        plan
    }

    suspend fun mergePersons(db: AppDb, store: Store, request: PersonMergeRequest, today: Long): PersonMergePlan = db.withTransaction {
        val devices = db.deviceDao().all(); val history = db.ownershipDao().all(); val entries = db.ledgerDao().allEntries()
        val plan = PersonMergePlanning.preview(request, devices, history, entries)
        require(plan.canApply) { "Manual Ledger conflict requires explicit choice" }
        val survivor = requireNotNull(db.personDao().byId(request.survivorId))
        val source = requireNotNull(db.personDao().byId(request.sourceId))
        devices.filter { it.ownerPersonId == source.id }.forEach { db.deviceDao().upsert(it.copy(ownerPersonId = survivor.id)) }
        history.filter { it.personId == source.id }.forEach {
            db.ownershipDao().delete(it.key)
            db.ownershipDao().upsert(it.copy(key = "${it.key}|merged", personId = survivor.id))
        }
        entries.filter { it.personId == source.id }.groupBy { it.monthKey }.forEach { (monthKey, sourceRows) ->
            val target = entries.find { it.monthKey == monthKey && it.personId == survivor.id }
            val usage = sourceRows.sumOf { it.usageGb } + (target?.usageGb ?: 0.0)
                val payment = sourceRows.sumOf { it.paidToman } + (target?.paidToman ?: 0L)
            val rate = survivor.rateOverride ?: target?.rateUsed ?: sourceRows.first().rateUsed
            val sourceNotes = sourceRows.map { it.note }.filter { it.isNotBlank() }.joinToString(" | ")
            val note = listOfNotNull(target?.note?.takeIf { it.isNotBlank() }, sourceNotes.takeIf { it.isNotBlank() }?.let { "ادغام از ${source.name}: $it" }).joinToString(" | ")
            val soleManual = listOfNotNull(target, *sourceRows.toTypedArray()).filter { it.edited || it.costOverride != null }.singleOrNull()
            val override = when (request.manualChoice) {
                MergeManualChoice.SURVIVOR -> target?.costOverride
                MergeManualChoice.SOURCE -> sourceRows.firstNotNullOfOrNull { it.costOverride }
                MergeManualChoice.REQUIRE_EXPLICIT -> soleManual?.costOverride
                MergeManualChoice.SUM_PAYMENTS -> null
            }
            val owed = override ?: Pricing.owedToman(usage, rate)
            db.ledgerDao().upsertEntry(LedgerEntryEntity("$monthKey|${survivor.id}", monthKey, survivor.id, usage, rate, owed, override, payment >= owed && owed > 0, payment, note, target?.edited == true || sourceRows.any { it.edited }))
            sourceRows.forEach { db.ledgerDao().deleteEntry(it.key) }
        }
        db.personDao().delete(source.id)
        db.ownershipAuditDao().insert(OwnershipAuditEntity(java.util.UUID.randomUUID().toString(), "merge", today, details = "source=${source.id};survivor=${survivor.id};choice=${request.manualChoice}"))
        reconcileAffectedMonths(db, store, plan.affectedMonthKeys, today)
        plan
    }

    private suspend fun reconcileAffectedMonths(db: AppDb, store: Store, keys: Set<String>, today: Long) {
        keys.forEach { key -> db.ledgerDao().month(key)?.let { month ->
            val start = jalaliDay(month.jYear, month.jMonth, 1)
            val next = if (month.jMonth == 12) jalaliDay(month.jYear + 1, 1, 1) else jalaliDay(month.jYear, month.jMonth + 1, 1)
            if (month.closedDay != null) db.ledgerDao().upsertMonth(month.copy(closedDay = null))
            reconcileMonthInTransaction(db, store, month.copy(closedDay = null), start, minOf(today, next - 1))
        } }
    }

    suspend fun setHideFromLedger(db: AppDb, store: Store, mac: String, hide: Boolean, today: Long) =
        db.withTransaction {
            val device = db.deviceDao().byMac(mac) ?: DeviceSettingsEntity(mac)
            db.deviceDao().upsert(device.copy(hideFromLedger = hide))
            reconcileCurrentMonth(db, store, today)
        }

    suspend fun updatePerson(db: AppDb, store: Store, person: PersonEntity, today: Long) =
        db.withTransaction {
            val oldRate = db.personDao().byId(person.id)?.rateOverride
            db.personDao().upsert(person)
            if (oldRate != person.rateOverride) reconcileCurrentMonth(db, store, today)
        }

    private suspend fun reconcileCurrentMonth(db: AppDb, store: Store, today: Long) {
        val jalali = jalaliOf(today)
        val key = MonthAttribution.key(jalali.year, jalali.month)
        val month = db.ledgerDao().month(key)
            ?: LedgerMonthEntity(key, jalali.year, jalali.month, store.defaultRate).also { db.ledgerDao().upsertMonth(it) }
        if (month.closedDay == null) reconcileMonthInTransaction(db, store, month, jalaliMonthStart(today), today)
    }

    private fun LedgerEntryEntity.toReconcileLine() = ReconcileLine(
        personId, usageGb, rateUsed, owedToman, costOverride, paid, paidToman, note, edited,
    )

    private fun ReconcileLine.toEntity(monthKey: String) = LedgerEntryEntity(
        key = "$monthKey|$personId", monthKey = monthKey, personId = personId,
        usageGb = usageGb, rateUsed = rateUsed, owedToman = owedToman,
        costOverride = costOverride, paid = paid, paidToman = paidToman, note = note, edited = edited,
    )

    suspend fun ensureUnassigned(db: AppDb) {
        if (db.personDao().byId(UNASSIGNED) == null) {
            db.personDao().upsert(PersonEntity(id = UNASSIGNED, name = "بدون مالک", implicit = true, archived = true))
        }
    }

    /**
     * Pulls the reachable past Gregorian months from /bill and attributes each to the
     * Jalali month it most belongs to. Idempotent and runs once (flag in [Store]).
     */
    suspend fun importRouterHistory(db: AppDb, store: Store, base: String, token: String): Boolean {
        if (base.isBlank() || token.isBlank()) return false
        val completed = store.importedRouterSourceMonths.toMutableSet()
        val currentJalali = jalaliOf(tehranDay(System.currentTimeMillis()))
        val currentKey = MonthAttribution.key(currentJalali.year, currentJalali.month)
        val calendar = Calendar.getInstance(TimeZone.getTimeZone("Asia/Tehran")).apply { set(Calendar.DAY_OF_MONTH, 1) }
        for (back in 0..17) {
            val year = calendar.get(Calendar.YEAR)
            val monthNumber = calendar.get(Calendar.MONTH) + 1
            val sourceKey = "$year-${monthNumber.toString().padStart(2, '0')}"
            calendar.add(Calendar.MONTH, -1)
            if (sourceKey in completed) continue
            val attributed = MonthAttribution.attribution(year, monthNumber)
            // daily_usage is authoritative for the live local month; never mix a Gregorian total into it.
            if (MonthAttribution.key(attributed.first, attributed.second) == currentKey) {
                completed += sourceKey
                store.importedRouterSourceMonths = completed
                continue
            }
            val bill = try {
                ApiClient.get<BillResponse>(base, token, "/bill", "month" to sourceKey)
            } catch (e: Exception) {
                e.rethrowIfCancellation()
                return false // retain already completed source months; WorkManager/app refresh resumes here
            }
            if (bill.total_gb > 0) importSourceMonth(db, store, sourceKey, attributed, bill.total_gb)
            completed += sourceKey
            store.importedRouterSourceMonths = completed
        }
        store.importedRouterHistory = true
        return true
    }

    private suspend fun importSourceMonth(
        db: AppDb, store: Store, sourceKey: String, attributed: Pair<Int, Int>, importedGb: Double,
    ) = db.withTransaction {
        ensureUnassigned(db)
        val (jy, jm) = attributed
        val monthKey = MonthAttribution.key(jy, jm)
        val month = db.ledgerDao().month(monthKey)
        db.ledgerDao().upsertMonth(
            month?.copy(imported = true) ?: LedgerMonthEntity(monthKey, jy, jm, store.defaultRate, imported = true),
        )
        // A source-specific row is the idempotency boundary; retries cannot add it twice.
        val rate = Pricing.resolveRate(store.defaultRate, month?.globalRate)
        db.ledgerDao().upsertEntry(
            LedgerEntryEntity(
                key = RouterImportTracking.entryKey(monthKey, sourceKey), monthKey = monthKey, personId = UNASSIGNED,
                usageGb = importedGb, rateUsed = rate, owedToman = Pricing.owedToman(importedGb, rate),
            ),
        )
    }
}