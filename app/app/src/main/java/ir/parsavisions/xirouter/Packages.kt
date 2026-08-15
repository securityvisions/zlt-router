package ir.parsavisions.xirouter

import androidx.room.Dao
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.withTransaction
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.sync.withLock
import java.time.LocalDate
import java.time.temporal.ChronoUnit

/** Router-owned Package fields plus phone-owned presentation, lifecycle, and alert metadata. */
@Entity(tableName = "packages")
data class PackageEntity(
    @PrimaryKey val id: String,
    val provider: String = "", val subscriber: String = "", val type: String = "", val routerName: String = "",
    val routerCategory: String = "", val window: String = "", val quotaGb: Double? = null,
    val remainGb: Double? = null, val consumedGb: Double? = null, val activation: String? = null,
    val expiry: String? = null, val status: String = "", val priority: Int = 0,
    val sourceAsOfUnix: Long = 0, val source: String = "", val lastSeenUnix: Long,
    val missingSuccessCount: Int = 0, val unconfirmed: Boolean = false, val archived: Boolean = false,
    val alias: String = "", val color: String = "", val localCategory: String = "",
    val visible: Boolean = true, val note: String = "", val displayOrder: Int = 0,
    val alertsMuted: Boolean = false, val alertThresholdPct: Int? = null,
)

@Entity(tableName = "package_snapshots", primaryKeys = ["packageId", "ts"])
data class PackageSnapshotEntity(
    val packageId: String, val ts: Long, val quotaGb: Double?, val remainGb: Double?,
    val consumedGb: Double?, val status: String, val expiry: String?,
)

/** Durable, sanitized transition identity; Package content remains in the Package table. */
@Entity(tableName = "pending_package_alerts")
data class PendingPackageAlertEntity(
    @PrimaryKey val key: String, val packageId: String, val kind: String,
)

@Dao
interface PackageDao {
    @Query("SELECT * FROM packages ORDER BY archived, unconfirmed, displayOrder, priority, id")
    fun allFlow(): Flow<List<PackageEntity>>
    @Query("SELECT * FROM packages") suspend fun all(): List<PackageEntity>
    @Query("SELECT * FROM packages WHERE id = :id") suspend fun byId(id: String): PackageEntity?
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun upsert(value: PackageEntity)
    @Insert(onConflict = OnConflictStrategy.REPLACE) suspend fun insertSnapshot(value: PackageSnapshotEntity)
    @Query("SELECT * FROM package_snapshots WHERE packageId = :id ORDER BY ts DESC LIMIT :limit")
    suspend fun snapshots(id: String, limit: Int = 90): List<PackageSnapshotEntity>
    @Query("DELETE FROM package_snapshots WHERE ts < :cutoff") suspend fun pruneSnapshots(cutoff: Long)
    @Query("DELETE FROM package_snapshots WHERE packageId = :id AND ts NOT IN (SELECT ts FROM package_snapshots WHERE packageId = :id ORDER BY ts DESC LIMIT :keep)")
    suspend fun compactSnapshots(id: String, keep: Int)
    @Query("SELECT * FROM pending_package_alerts ORDER BY `key`") suspend fun pendingAlerts(): List<PendingPackageAlertEntity>
    @Insert(onConflict = OnConflictStrategy.IGNORE) suspend fun enqueueAlert(value: PendingPackageAlertEntity)
    @Query("DELETE FROM pending_package_alerts WHERE `key` IN (:keys)") suspend fun clearAlerts(keys: List<String>)
}

object PackageIdentity {
    /** IDs are opaque Router API identity. Invalid rows are ignored; fields never synthesize identity. */
    fun unique(rows: List<PackageDto>): List<PackageDto> = rows.filter { it.id.isNotBlank() }.distinctBy { it.id }
}

object PackageLifecycle {
    const val ARCHIVE_AFTER_MISSES = 3
    fun missing(old: PackageEntity): PackageEntity {
        val misses = old.missingSuccessCount + 1
        return old.copy(missingSuccessCount = misses, unconfirmed = misses < ARCHIVE_AFTER_MISSES,
            archived = misses >= ARCHIVE_AFTER_MISSES)
    }

    fun merge(dto: PackageDto, old: PackageEntity?, nowUnix: Long): PackageEntity = PackageEntity(
        id = dto.id, provider = dto.provider.orEmpty(), subscriber = dto.subscriber.orEmpty(),
        type = dto.type.orEmpty(), routerName = dto.name.orEmpty(), routerCategory = dto.category.orEmpty(),
        window = dto.window.orEmpty(), quotaGb = dto.quota_gb, remainGb = dto.remain_gb,
        consumedGb = dto.consumed_gb, activation = dto.activation, expiry = dto.expiry,
        status = dto.status.orEmpty(), priority = dto.priority, sourceAsOfUnix = dto.freshness?.as_of_unix ?: nowUnix,
        source = dto.freshness?.source.orEmpty(), lastSeenUnix = nowUnix,
        alias = old?.alias.orEmpty(), color = old?.color.orEmpty(), localCategory = old?.localCategory.orEmpty(),
        visible = old?.visible ?: true, note = old?.note.orEmpty(), displayOrder = old?.displayOrder ?: 0,
        alertsMuted = old?.alertsMuted ?: false, alertThresholdPct = old?.alertThresholdPct,
    )
}

data class PackageIntelligence(val remainingPct: Int?, val daysToExpiry: Long?, val depletionDays: Double?)
object PackageInsights {
    fun calculate(p: PackageEntity, dailyConsumptionGb: Double, today: LocalDate = LocalDate.now()): PackageIntelligence {
        val pct = p.remainGb?.let { remain -> p.quotaGb?.takeIf { it > 0 }?.let { (remain / it * 100).toInt().coerceIn(0, 100) } }
        val expiry = p.expiry?.let { runCatching { ChronoUnit.DAYS.between(today, LocalDate.parse(it)) }.getOrNull() }
        val depletion = p.remainGb?.takeIf { dailyConsumptionGb > 0 }?.div(dailyConsumptionGb)
        return PackageIntelligence(pct, expiry, depletion)
    }

    /** Consumption rate from durable Package history, robust to repeated polls and counter resets. */
    fun dailyConsumption(snapshots: List<PackageSnapshotEntity>): Double {
        val ordered = snapshots.filter { it.remainGb != null }.sortedBy { it.ts }
        if (ordered.size < 2) return 0.0
        val first = ordered.first(); val last = ordered.last()
        val days = (last.ts - first.ts) / 86_400.0
        return if (days > 0) ((first.remainGb!! - last.remainGb!!).coerceAtLeast(0.0) / days) else 0.0
    }
}

enum class PackageDisplayMode(val value: String) { AGGREGATE("aggregate"), SEGMENTED("segmented"), PACKAGE("package");
    companion object { fun parse(value: String?) = entries.firstOrNull { it.value == value } ?: AGGREGATE }
}

enum class PackageAlertKind { LOW, DEPLETED, NEW, DISAPPEARED, EXPIRY }
data class PackageAlert(val packageId: String, val kind: PackageAlertKind) {
    fun pending() = PendingPackageAlertEntity("$packageId:${kind.name}", packageId, kind.name)
}

object PackageAlertDelivery {
    fun shouldClear(outcome: NotificationDeliveryOutcome): Boolean =
        notificationCycleOutcome(outcome) == NotificationCycleDecision.Advance
    fun remaining(alerts: List<PackageAlert>, outcome: NotificationDeliveryOutcome): List<PackageAlert> =
        if (shouldClear(outcome)) emptyList() else alerts
}

object PackageAlerts {
    private const val EXPIRY_DAYS = 3L

    fun calculate(
        previous: PackageEntity?, current: PackageEntity, globalEnabled: Boolean,
        defaultThreshold: Int, today: LocalDate = LocalDate.now(), establishedBaseline: Boolean = false,
    ): List<PackageAlert> {
        if (!globalEnabled || current.alertsMuted || current.archived) return emptyList()
        if (previous == null) return if (establishedBaseline) listOf(PackageAlert(current.id, PackageAlertKind.NEW)) else emptyList()
        if (previous.archived) return listOf(PackageAlert(current.id, PackageAlertKind.NEW))
        val threshold = current.alertThresholdPct ?: defaultThreshold
        val now = PackageInsights.calculate(current, 0.0, today)
        val before = PackageInsights.calculate(previous, 0.0, today)
        val alerts = mutableListOf<PackageAlert>()
        if (now.remainingPct != null && now.remainingPct <= threshold && (before.remainingPct == null || before.remainingPct > threshold))
            alerts += PackageAlert(current.id, PackageAlertKind.LOW)
        if (current.status.equals("depleted", true) && !previous.status.equals("depleted", true))
            alerts += PackageAlert(current.id, PackageAlertKind.DEPLETED)
        if (now.daysToExpiry != null && now.daysToExpiry in 0..EXPIRY_DAYS && (before.daysToExpiry == null || before.daysToExpiry > EXPIRY_DAYS))
            alerts += PackageAlert(current.id, PackageAlertKind.EXPIRY)
        return alerts
    }

    fun missing(previous: PackageEntity, current: PackageEntity, globalEnabled: Boolean): List<PackageAlert> =
        if (globalEnabled && !previous.alertsMuted && !previous.archived && current.archived)
            listOf(PackageAlert(current.id, PackageAlertKind.DISAPPEARED)) else emptyList()
}

object PackageSync {
    /** Cached or timestamp-less empty answers are not authoritative absence. */
    fun authoritative(response: BalanceResponse): Boolean = !response.cached && response.as_of_unix > 0
    fun acceptsRow(previous: PackageEntity?, sourceAsOfUnix: Long): Boolean =
        previous == null || sourceAsOfUnix >= previous.sourceAsOfUnix
    fun acceptsMissing(previous: PackageEntity, responseAsOfUnix: Long): Boolean =
        responseAsOfUnix > previous.sourceAsOfUnix

    suspend fun sync(
        db: AppDb, response: BalanceResponse, nowUnix: Long,
        globalAlertsEnabled: Boolean = false, defaultThreshold: Int = 20,
        establishedBaseline: Boolean = false,
    ): List<PackageAlert> = db.withTransaction {
        val dao = db.packageDao()
        val incoming = PackageIdentity.unique(response.packages)
        val old = dao.all().associateBy { it.id }
        val alerts = mutableListOf<PackageAlert>()
        incoming.forEach { dto ->
            val sourceAsOfUnix = dto.freshness?.as_of_unix?.takeIf { it > 0 } ?: response.as_of_unix
            val previous = old[dto.id]
            if (!acceptsRow(previous, sourceAsOfUnix)) return@forEach
            val merged = PackageLifecycle.merge(dto, previous, nowUnix).copy(sourceAsOfUnix = sourceAsOfUnix)
            alerts += PackageAlerts.calculate(previous, merged, globalAlertsEnabled, defaultThreshold, establishedBaseline = establishedBaseline)
            dao.upsert(merged)
            dao.insertSnapshot(PackageSnapshotEntity(merged.id, sourceAsOfUnix, merged.quotaGb, merged.remainGb, merged.consumedGb, merged.status, merged.expiry))
            dao.compactSnapshots(merged.id, 180)
        }
        if (authoritative(response)) {
            (old.keys - incoming.map { it.id }.toSet()).forEach {
                val previous = old.getValue(it)
                if (!acceptsMissing(previous, response.as_of_unix)) return@forEach
                val missing = PackageLifecycle.missing(previous)
                alerts += PackageAlerts.missing(previous, missing, globalAlertsEnabled)
                dao.upsert(missing)
            }
        }
        alerts.forEach { dao.enqueueAlert(it.pending()) }
        dao.pruneSnapshots(nowUnix - 365L * 86_400L)
        alerts
    }
}

/** The single serialized ingestion path shared by foreground refresh and polling. */
class PackageIngestion(private val context: android.content.Context) {
    private val appContext = context.applicationContext
    private val db = AppDb.get(appContext)
    private val store = Store(appContext)

    suspend fun ingest(response: BalanceResponse): List<PackageAlert> = mutex.withLock {
        val authoritative = PackageSync.authoritative(response)
        val alerts = PackageSync.sync(db, response, response.as_of_unix.takeIf { it > 0 } ?: System.currentTimeMillis() / 1000,
            store.packageAlerts, store.packageAlertThresholdPct, store.packageBaselineEstablished)
        if (authoritative) store.packageBaselineEstablished = true
        check(deliverPending() != NotificationDeliveryOutcome.Error) { "Package notification delivery failed" }
        alerts
    }

    suspend fun retryPending(): NotificationDeliveryOutcome = mutex.withLock { deliverPending() }

    private suspend fun deliverPending(): NotificationDeliveryOutcome {
        val dao = db.packageDao()
        val rows = dao.pendingAlerts()
        if (rows.isEmpty()) return NotificationDeliveryOutcome.Disabled
        val packages = dao.all().associateBy { it.id }
        val alerts = if (!store.packageAlerts) emptyList() else rows.mapNotNull { row ->
            runCatching { PackageAlert(row.packageId, PackageAlertKind.valueOf(row.kind)) }.getOrNull()
                ?.takeUnless { packages[it.packageId]?.alertsMuted == true }
        }
        val outcome = Notifier.postPackages(appContext, alerts, packages)
        if (PackageAlertDelivery.shouldClear(outcome)) dao.clearAlerts(rows.map { it.key })
        return outcome
    }

    companion object { private val mutex = kotlinx.coroutines.sync.Mutex() }
}
