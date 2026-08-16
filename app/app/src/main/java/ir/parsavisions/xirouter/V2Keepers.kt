package ir.parsavisions.xirouter

import kotlinx.serialization.json.Json
import java.util.UUID

/**
 * v2 keepers — thin DB adapters over the pure domain seams (V2Domain.kt).
 * All decision math lives in V2Domain; these only write rows and return ids.
 */
object V2Keepers {
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    // ── Payments (ADR-0001) ──────────────────────────────────────────────────

    /** Record a payment and audit it. Returns the payment id. */
    suspend fun recordPayment(db: AppDb, personId: String, monthKey: String, amountToman: Long, atMillis: Long, method: String, note: String): String {
        val id = "pmt-" + UUID.randomUUID().toString().take(8)
        db.paymentDao().insert(
            PaymentEntity(
                id = id, personId = personId, monthKey = monthKey,
                amountToman = amountToman.coerceAtLeast(0), atMillis = atMillis,
                method = method.trim(), note = note.trim(),
            ),
        )
        db.auditDao().insert(
            AuditEventEntity(
                id = "aud-" + UUID.randomUUID().toString().take(8),
                kind = "payment", details = "$personId $monthKey +$amountToman",
            ),
        )
        return id
    }

    /** Apply a person's credit oldest-unpaid-first across their unpaid bills. */
    suspend fun applyCreditToBills(db: AppDb, personId: String) {
        val person = db.personDao().byId(personId) ?: return
        if (person.creditToman <= 0) return
        val unpaid = db.ledgerDao().allEntries().filter { it.personId == personId && PaymentMath.billTotal(it) > it.paidToman }
            .map { it.monthKey to (PaymentMath.billTotal(it) - it.paidToman) }
        val applied = PaymentMath.applyCreditToBills(person.creditToman, unpaid)
        if (applied.isEmpty()) return
        applied.forEach { (monthKey, amount) ->
            val entry = db.ledgerDao().allEntries().find { it.monthKey == monthKey && it.personId == personId } ?: return@forEach
            db.ledgerDao().upsertEntry(entry.copy(paidToman = entry.paidToman + amount, paid = true))
        }
        db.personDao().upsert(person.copy(creditToman = person.creditToman - applied.values.sum()))
    }

    // ── Inbox / timeline / audit (ADR-0004/0005) ─────────────────────────────

    suspend fun inbox(db: AppDb, kind: String, title: String, body: String = ""): String {
        val id = "inb-" + UUID.randomUUID().toString().take(8)
        db.inboxDao().insert(InboxEventEntity(id = id, kind = kind, title = title, body = body))
        return id
    }

    suspend fun activity(db: AppDb, category: String, kind: String, title: String) {
        db.activityDao().insert(
            ActivityEventEntity(
                id = "act-" + UUID.randomUUID().toString().take(8),
                category = category, kind = kind, title = title,
            ),
        )
    }

    suspend fun audit(db: AppDb, kind: String, details: String, actor: String = "local") {
        db.auditDao().insert(
            AuditEventEntity(
                id = "aud-" + UUID.randomUUID().toString().take(8),
                kind = kind, details = details, actor = actor,
            ),
        )
    }

    /** Prune the activity timeline past 180 days (audit is never pruned). */
    suspend fun pruneActivity(db: AppDb) {
        db.activityDao().prune(System.currentTimeMillis() - 180L * 86_400_000L)
    }

    // ── Automation (ADR-0002) ────────────────────────────────────────────────

    /**
     * Evaluate every enabled rule against the context and fire the rising-edge
     * ones (recordRun guards re-fire while still true). Fire state is derived
     * from lastRunAt: a rule that fired stays "fired" until its condition goes
     * false again, tracked by the caller via the last evaluation.
     */
    suspend fun runAutomation(db: AppDb, ctx: AutomationContext, prevFired: Map<String, Boolean>): Map<String, Boolean> {
        val next = prevFired.toMutableMap()
        db.automationDao().enabled().forEach { rule ->
            val codec = AutomationEngine.decode(json, rule.conditionJson) ?: return@forEach
            val fires = AutomationEngine.evaluate(codec.condition, ctx)
            val shouldFire = AutomationEngine.shouldFire(prevFired[rule.id] ?: false, fires)
            next[rule.id] = fires
            if (shouldFire) {
                db.automationDao().recordRun(rule.id, System.currentTimeMillis())
                db.inboxDao().insert(
                    InboxEventEntity(
                        id = "inb-" + UUID.randomUUID().toString().take(8),
                        kind = "automation", title = rule.name,
                        body = "Automation rule fired: ${codec.name}",
                    ),
                )
            }
        }
        return next
    }

    // ── Quota crossings (ADR-0003) ───────────────────────────────────────────

    /**
     * Diff each person's quota level vs the stored last level; write inbox +
     * activity rows for new escalations. Returns the updated level map.
     */
    suspend fun runQuotaCheck(db: AppDb, prevLevels: Map<String, String>, now: Long): Map<String, String> {
        val next = prevLevels.toMutableMap()
        db.personDao().all().forEach { person ->
            val used = db.ledgerDao().allEntries().filter { it.personId == person.id }.sumOf { it.usageGb }
            val current = QuotaCrossing.level(used, person.quotaGb, 70, 90)
            val prev = prevLevels[person.id] ?: QuotaCrossing.NONE
            QuotaCrossing.crossings(prev, current).forEach { kind ->
                V2Keepers.inbox(db, kind, "سقف مصرف: ${person.name}", "used=${"%.1f".format(used)} GB")
                V2Keepers.activity(db, "billing", kind, "سقف مصرف ${person.name} رد شد")
            }
            next[person.id] = current
        }
        return next
    }
}
