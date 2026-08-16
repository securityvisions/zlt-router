package ir.parsavisions.xirouter

import android.content.Context
import androidx.room.Dao
import androidx.room.Database
import androidx.room.Entity
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.PrimaryKey
import androidx.room.Query
import androidx.room.Room
import androidx.room.Update
import androidx.room.RoomDatabase
import androidx.room.ColumnInfo
import androidx.room.migration.Migration
import androidx.sqlite.db.SupportSQLiteDatabase
import kotlinx.coroutines.flow.Flow

// ── Monitor history (kept from v1) ────────────────────────────────────────────

/** One local history sample: the phone's second store (the router keeps its own logs). */
@Entity(tableName = "samples")
data class SampleEntity(
    @PrimaryKey val ts: Long,
    val kind: String,
    val value: Double,
)

@Dao
interface SampleDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(sample: SampleEntity)

    @Query("SELECT * FROM samples WHERE kind = :kind AND ts >= :fromTs ORDER BY ts ASC")
    suspend fun between(kind: String, fromTs: Long): List<SampleEntity>

    @Query("SELECT * FROM samples WHERE kind = :kind AND ts >= :fromTs ORDER BY ts ASC")
    fun betweenFlow(kind: String, fromTs: Long): Flow<List<SampleEntity>>

    @Query("DELETE FROM samples WHERE ts < :cutoff")
    suspend fun prune(cutoff: Long)

    @Query("SELECT * FROM samples WHERE kind = :kind ORDER BY ts DESC LIMIT 1")
    suspend fun latest(kind: String): SampleEntity?

    @Query("SELECT MAX(ts) FROM samples")
    suspend fun latestTimestamp(): Long?
}

// ── Billing ledger (v2) ──────────────────────────────────────────────────────

/** A named billing entity; owns zero or more device MACs (see device_settings). */
@Entity(tableName = "persons")
data class PersonEntity(
    @PrimaryKey val id: String,
    val name: String,
    val group: String = "",
    val colorIndex: Int = 0,
    val note: String = "",
    val rateOverride: Long? = null,
    val archived: Boolean = false,
    val implicit: Boolean = false,
    // v6: person credit + quota (ADR-0001/ADR-0003)
    @ColumnInfo(defaultValue = "0") val creditToman: Long = 0,
    val quotaGb: Double? = null,
)

/** Per-MAC local customization and ownership; router writes `name` via /devices. */
@Entity(tableName = "device_settings")
data class DeviceSettingsEntity(
    @PrimaryKey val mac: String,
    val ownerPersonId: String? = null,
    val alias: String = "",
    val category: String = "",
    val note: String = "",
    val hideFromLedger: Boolean = false,
    val watched: Boolean = false,
    val lastSeenName: String = "",
    // v6 device enrichment (ADR-0009) — SQL defaults match the ALTER TABLE
    // migration (SQLite requires a default when adding a NOT NULL column).
    @ColumnInfo(defaultValue = "''") val ip: String = "",
    @ColumnInfo(defaultValue = "''") val deviceType: String = "",
    @ColumnInfo(defaultValue = "''") val tags: String = "",
    @ColumnInfo(defaultValue = "0") val lastSeenUnix: Long = 0,
    @ColumnInfo(defaultValue = "0") val excludeFromAnalytics: Boolean = false,
)

/** Ownership memory — keeps soft history (untilDay set) for the suggestion engine. */
@Entity(tableName = "ownership_history")
data class OwnershipHistoryEntity(
    @PrimaryKey val key: String,
    val mac: String,
    val personId: String,
    val sinceDay: Long,
    val untilDay: Long? = null,
)

/** One Jalali month of the ledger (monthKey = "1405/05"). */
@Entity(tableName = "ledger_months")
data class LedgerMonthEntity(
    @PrimaryKey val key: String,
    val jYear: Int,
    val jMonth: Int,
    val globalRate: Long,
    val note: String = "",
    val imported: Boolean = false,
    val closedDay: Long? = null,
)

/** One person's row inside a month. */
@Entity(tableName = "ledger_entries")
data class LedgerEntryEntity(
    @PrimaryKey val key: String,
    val monthKey: String,
    val personId: String,
    val usageGb: Double = 0.0,
    val rateUsed: Long,
    val owedToman: Long = 0,
    val costOverride: Long? = null,
    val paid: Boolean = false,
    val paidToman: Long = 0,
    val note: String = "",
    val edited: Boolean = false,
)

/** The app's own per-day per-device measure — the exact Jalali-month source. */
@Entity(tableName = "daily_usage")
data class DailyUsageEntity(
    @PrimaryKey val key: String,
    val day: Long,
    val mac: String,
    val gb: Double,
)

@Entity(tableName = "ownership_audit")
data class OwnershipAuditEntity(
    @PrimaryKey val id: String,
    val kind: String,
    val effectiveDay: Long,
    val actor: String = "local",
    val details: String,
    val createdAt: Long = System.currentTimeMillis(),
)

@Entity(tableName = "suggestion_dismissals")
data class SuggestionDismissalEntity(
    @PrimaryKey val key: String,
    val mac: String,
    val personId: String,
    val dismissedAt: Long = System.currentTimeMillis(),
)

@Dao
interface PersonDao {
    @Query("SELECT * FROM persons ORDER BY archived ASC, name ASC")
    fun allFlow(): Flow<List<PersonEntity>>

    @Query("SELECT * FROM persons")
    suspend fun all(): List<PersonEntity>

    @Query("SELECT * FROM persons WHERE id = :id")
    suspend fun byId(id: String): PersonEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(person: PersonEntity)

    @Query("UPDATE persons SET archived = 1 WHERE id = :id")
    suspend fun archive(id: String)

    @Query("UPDATE persons SET archived = 0 WHERE id = :id")
    suspend fun restore(id: String)

    @Query("DELETE FROM persons WHERE id = :id")
    suspend fun delete(id: String)

    @Query("SELECT * FROM persons WHERE archived = 0 AND id NOT IN ('__unassigned__') ORDER BY name ASC")
    suspend fun editable(): List<PersonEntity>
}

@Dao
interface DeviceDao {
    @Query("SELECT * FROM device_settings ORDER BY mac ASC")
    fun allFlow(): Flow<List<DeviceSettingsEntity>>

    @Query("SELECT * FROM device_settings ORDER BY mac ASC")
    suspend fun all(): List<DeviceSettingsEntity>

    @Query("SELECT * FROM device_settings WHERE mac = :mac")
    suspend fun byMac(mac: String): DeviceSettingsEntity?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(device: DeviceSettingsEntity)

    @Query("SELECT * FROM device_settings WHERE ownerPersonId = :personId")
    suspend fun byOwner(personId: String): List<DeviceSettingsEntity>

    @Query("SELECT COUNT(*) FROM device_settings WHERE ownerPersonId = :personId")
    suspend fun ownedCount(personId: String): Int
}

@Dao
interface OwnershipDao {
    @Query("SELECT * FROM ownership_history")
    fun allFlow(): Flow<List<OwnershipHistoryEntity>>

    @Query("SELECT * FROM ownership_history")
    suspend fun all(): List<OwnershipHistoryEntity>

    @Query("SELECT * FROM ownership_history WHERE mac = :mac")
    suspend fun forMac(mac: String): List<OwnershipHistoryEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(history: OwnershipHistoryEntity)

    @Query("UPDATE ownership_history SET untilDay = :untilDay WHERE mac = :mac AND untilDay IS NULL")
    suspend fun closeAll(mac: String, untilDay: Long)

    @Query("UPDATE ownership_history SET untilDay = :untilDay WHERE mac = :mac AND personId = :personId AND untilDay IS NULL")
    suspend fun closeActive(mac: String, personId: String, untilDay: Long)

    @Query("DELETE FROM ownership_history WHERE `key` = :key")
    suspend fun delete(key: String)
}

@Dao
interface OwnershipAuditDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(value: OwnershipAuditEntity)

    @Query("SELECT * FROM ownership_audit ORDER BY createdAt DESC")
    suspend fun all(): List<OwnershipAuditEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun dismiss(value: SuggestionDismissalEntity)

    @Query("DELETE FROM suggestion_dismissals WHERE `key` = :key")
    suspend fun undoDismissal(key: String)

    @Query("SELECT * FROM suggestion_dismissals")
    suspend fun dismissals(): List<SuggestionDismissalEntity>
}

@Dao
interface LedgerDao {
    @Query("SELECT * FROM ledger_months ORDER BY jYear DESC, jMonth DESC")
    fun monthsFlow(): Flow<List<LedgerMonthEntity>>

    @Query("SELECT * FROM ledger_months ORDER BY jYear DESC, jMonth DESC")
    suspend fun allMonths(): List<LedgerMonthEntity>

    @Query("SELECT * FROM ledger_months WHERE key = :key")
    suspend fun month(key: String): LedgerMonthEntity?

    @Query("SELECT * FROM ledger_months WHERE jYear = :year ORDER BY jMonth ASC")
    suspend fun yearMonths(year: Int): List<LedgerMonthEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertMonth(month: LedgerMonthEntity)

    @Query("SELECT * FROM ledger_entries WHERE monthKey = :monthKey ORDER BY personId ASC")
    fun entriesFlow(monthKey: String): Flow<List<LedgerEntryEntity>>

    @Query("SELECT * FROM ledger_entries WHERE monthKey = :monthKey ORDER BY personId ASC")
    suspend fun entries(monthKey: String): List<LedgerEntryEntity>

    @Query("SELECT * FROM ledger_entries")
    fun allEntriesFlow(): Flow<List<LedgerEntryEntity>>

    @Query("SELECT * FROM ledger_entries")
    suspend fun allEntries(): List<LedgerEntryEntity>

    @Query("SELECT * FROM ledger_entries WHERE monthKey LIKE :year || '/%' ORDER BY personId ASC")
    suspend fun yearEntries(year: Int): List<LedgerEntryEntity>

    @Query("SELECT * FROM ledger_entries WHERE personId = :personId ORDER BY monthKey ASC")
    fun personEntriesFlow(personId: String): Flow<List<LedgerEntryEntity>>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertEntry(entry: LedgerEntryEntity)

    @Query("DELETE FROM ledger_entries WHERE key = :key")
    suspend fun deleteEntry(key: String)

    @Query("UPDATE ledger_entries SET owedToman = :owed, costOverride = :costOverride, paid = :paid, paidToman = :paidToman, note = :note, edited = 1 WHERE key = :key")
    suspend fun updateManualFields(
        key: String,
        owed: Long,
        costOverride: Long?,
        paid: Boolean,
        paidToman: Long,
        note: String,
    )

    // ── daily usage ──

    @Query("SELECT * FROM daily_usage WHERE day >= :from AND day <= :to ORDER BY day ASC, mac ASC")
    suspend fun daysBetween(from: Long, to: Long): List<DailyUsageEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertDaily(usage: DailyUsageEntity)

    @Query("SELECT MAX(day) FROM daily_usage")
    suspend fun latestDay(): Long?
}

// ── v6 domain surfaces (ADR-0001…0011) ───────────────────────────────────────

/** One first-class payment against a person's bill (ADR-0001). */
@Entity(tableName = "payments")
data class PaymentEntity(
    @PrimaryKey val id: String,
    val personId: String,
    val monthKey: String,
    val amountToman: Long,
    val atMillis: Long,
    val method: String = "",
    val note: String = "",
    val createdAt: Long = System.currentTimeMillis(),
)

@Dao
interface PaymentDao {
    @Query("SELECT * FROM payments WHERE monthKey = :monthKey ORDER BY atMillis ASC")
    fun forMonthFlow(monthKey: String): Flow<List<PaymentEntity>>

    @Query("SELECT * FROM payments WHERE monthKey = :monthKey ORDER BY atMillis ASC")
    suspend fun forMonth(monthKey: String): List<PaymentEntity>

    @Query("SELECT * FROM payments WHERE personId = :personId ORDER BY atMillis ASC")
    suspend fun forPerson(personId: String): List<PaymentEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(payment: PaymentEntity)

    @Query("DELETE FROM payments WHERE id = :id")
    suspend fun delete(id: String)
}

/** In-app alert inbox (ADR-0004): unread/read/acknowledged, per-kind mute. */
@Entity(tableName = "inbox_events")
data class InboxEventEntity(
    @PrimaryKey val id: String,
    val kind: String,
    val title: String,
    val body: String = "",
    val atMillis: Long = System.currentTimeMillis(),
    val state: String = "unread",
    val muted: Boolean = false,
)

@Dao
interface InboxDao {
    @Query("SELECT * FROM inbox_events ORDER BY atMillis DESC")
    fun allFlow(): Flow<List<InboxEventEntity>>

    @Query("SELECT * FROM inbox_events ORDER BY atMillis DESC")
    suspend fun all(): List<InboxEventEntity>

    @Query("SELECT * FROM inbox_events WHERE state = 'unread'")
    suspend fun unread(): List<InboxEventEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(event: InboxEventEntity)

    @Query("UPDATE inbox_events SET state = :state WHERE id = :id")
    suspend fun setState(id: String, state: String)

    @Query("UPDATE inbox_events SET muted = :muted WHERE kind = :kind")
    suspend fun setKindMuted(kind: String, muted: Boolean)

    @Query("DELETE FROM inbox_events WHERE id = :id")
    suspend fun delete(id: String)
}

/** Prunable activity timeline (ADR-0005). */
@Entity(tableName = "activity_events")
data class ActivityEventEntity(
    @PrimaryKey val id: String,
    val category: String,
    val kind: String,
    val title: String,
    val atMillis: Long = System.currentTimeMillis(),
)

@Dao
interface ActivityDao {
    @Query("SELECT * FROM activity_events ORDER BY atMillis DESC")
    fun allFlow(): Flow<List<ActivityEventEntity>>

    @Query("SELECT * FROM activity_events WHERE category = :category ORDER BY atMillis DESC")
    suspend fun forCategory(category: String): List<ActivityEventEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(event: ActivityEventEntity)

    @Query("DELETE FROM activity_events WHERE atMillis < :cutoff")
    suspend fun prune(cutoff: Long)
}

/** Permanent billing/mutation audit (ADR-0005); never pruned. */
@Entity(tableName = "audit_events")
data class AuditEventEntity(
    @PrimaryKey val id: String,
    val kind: String,
    val actor: String = "local",
    val details: String,
    val createdAt: Long = System.currentTimeMillis(),
)

@Dao
interface AuditDao {
    @Query("SELECT * FROM audit_events ORDER BY createdAt DESC")
    suspend fun all(): List<AuditEventEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(event: AuditEventEntity)
}

/** Serializable WHEN/IF/THEN automation rule (ADR-0002). */
@Entity(tableName = "automation_rules")
data class AutomationRuleEntity(
    @PrimaryKey val id: String,
    val name: String,
    val conditionJson: String,
    val actionJson: String,
    val enabled: Boolean = true,
    val runCount: Int = 0,
    val lastRunAt: Long = 0,
)

@Dao
interface AutomationDao {
    @Query("SELECT * FROM automation_rules ORDER BY name ASC")
    fun allFlow(): Flow<List<AutomationRuleEntity>>

    @Query("SELECT * FROM automation_rules WHERE enabled = 1")
    suspend fun enabled(): List<AutomationRuleEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(rule: AutomationRuleEntity)

    @Query("UPDATE automation_rules SET runCount = runCount + 1, lastRunAt = :at WHERE id = :id")
    suspend fun recordRun(id: String, at: Long)

    @Query("UPDATE automation_rules SET enabled = :enabled WHERE id = :id")
    suspend fun setEnabled(id: String, enabled: Boolean)

    @Query("DELETE FROM automation_rules WHERE id = :id")
    suspend fun delete(id: String)
}

/** Saved filter view on the Ledger or Device workspace (ADR-0007). */
@Entity(tableName = "saved_views")
data class SavedViewEntity(
    @PrimaryKey val id: String,
    val title: String,
    val scope: String,
    val filterJson: String,
    val createdAt: Long = System.currentTimeMillis(),
)

@Dao
interface SavedViewDao {
    @Query("SELECT * FROM saved_views WHERE scope = :scope ORDER BY title ASC")
    suspend fun forScope(scope: String): List<SavedViewEntity>

    @Query("SELECT * FROM saved_views")
    suspend fun all(): List<SavedViewEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(view: SavedViewEntity)

    @Query("DELETE FROM saved_views WHERE id = :id")
    suspend fun delete(id: String)
}

/** Persian message template for per-person bills (ADR-0011). */
@Entity(tableName = "message_templates")
data class MessageTemplateEntity(
    @PrimaryKey val id: String,
    val title: String,
    val body: String,
    val createdAt: Long = System.currentTimeMillis(),
)

@Dao
interface MessageTemplateDao {
    @Query("SELECT * FROM message_templates ORDER BY title ASC")
    suspend fun all(): List<MessageTemplateEntity>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsert(template: MessageTemplateEntity)

    @Query("DELETE FROM message_templates WHERE id = :id")
    suspend fun delete(id: String)
}

@Database(
    entities = [
        SampleEntity::class, PersonEntity::class, DeviceSettingsEntity::class,
        OwnershipHistoryEntity::class, LedgerMonthEntity::class, LedgerEntryEntity::class,
        DailyUsageEntity::class, PackageEntity::class, PackageSnapshotEntity::class,
        PendingPackageAlertEntity::class, OwnershipAuditEntity::class, SuggestionDismissalEntity::class,
        PaymentEntity::class, InboxEventEntity::class, ActivityEventEntity::class,
        AuditEventEntity::class, AutomationRuleEntity::class, SavedViewEntity::class,
        MessageTemplateEntity::class,
    ],
    version = 6,
    exportSchema = true,
)
abstract class AppDb : RoomDatabase() {
    abstract fun sampleDao(): SampleDao
    abstract fun personDao(): PersonDao
    abstract fun deviceDao(): DeviceDao
    abstract fun ownershipDao(): OwnershipDao
    abstract fun ledgerDao(): LedgerDao
    abstract fun packageDao(): PackageDao
    abstract fun ownershipAuditDao(): OwnershipAuditDao
    abstract fun paymentDao(): PaymentDao
    abstract fun inboxDao(): InboxDao
    abstract fun activityDao(): ActivityDao
    abstract fun auditDao(): AuditDao
    abstract fun automationDao(): AutomationDao
    abstract fun savedViewDao(): SavedViewDao
    abstract fun messageTemplateDao(): MessageTemplateDao

    companion object {
        @Volatile private var instance: AppDb? = null

        fun get(context: Context): AppDb = instance ?: synchronized(this) {
            instance ?: Room.databaseBuilder(context.applicationContext, AppDb::class.java, "xirouter.db")
                .addMigrations(MIGRATION_1_2, MIGRATION_2_3, MIGRATION_3_4, MIGRATION_4_5, MIGRATION_5_6)
                .build()
                .also { instance = it }
        }

        /** v5→v6 (ADR-0001…0011): new domain surfaces over the existing ledger. */
        val MIGRATION_5_6 = object : Migration(5, 6) {
            override fun migrate(db: SupportSQLiteDatabase) {
                // device enrichment columns
                db.execSQL("ALTER TABLE device_settings ADD COLUMN ip TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE device_settings ADD COLUMN deviceType TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE device_settings ADD COLUMN tags TEXT NOT NULL DEFAULT ''")
                db.execSQL("ALTER TABLE device_settings ADD COLUMN lastSeenUnix INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE device_settings ADD COLUMN excludeFromAnalytics INTEGER NOT NULL DEFAULT 0")
                // person credit + quota
                db.execSQL("ALTER TABLE persons ADD COLUMN creditToman INTEGER NOT NULL DEFAULT 0")
                db.execSQL("ALTER TABLE persons ADD COLUMN quotaGb REAL")
                // payments (first-class; seeded from the legacy paidToman field)
                db.execSQL("CREATE TABLE IF NOT EXISTS payments (id TEXT NOT NULL PRIMARY KEY, personId TEXT NOT NULL, monthKey TEXT NOT NULL, amountToman INTEGER NOT NULL, atMillis INTEGER NOT NULL, method TEXT NOT NULL, note TEXT NOT NULL, createdAt INTEGER NOT NULL)")
                db.execSQL("INSERT OR IGNORE INTO payments (id, personId, monthKey, amountToman, atMillis, method, note, createdAt) SELECT 'migration:' || `key`, personId, monthKey, paidToman, 0, '', 'migrated', 0 FROM ledger_entries WHERE paidToman > 0")
                // inbox
                db.execSQL("CREATE TABLE IF NOT EXISTS inbox_events (id TEXT NOT NULL PRIMARY KEY, kind TEXT NOT NULL, title TEXT NOT NULL, body TEXT NOT NULL, atMillis INTEGER NOT NULL, state TEXT NOT NULL, muted INTEGER NOT NULL)")
                // activity timeline
                db.execSQL("CREATE TABLE IF NOT EXISTS activity_events (id TEXT NOT NULL PRIMARY KEY, category TEXT NOT NULL, kind TEXT NOT NULL, title TEXT NOT NULL, atMillis INTEGER NOT NULL)")
                // permanent audit (copies the legacy ownership audit)
                db.execSQL("CREATE TABLE IF NOT EXISTS audit_events (id TEXT NOT NULL PRIMARY KEY, kind TEXT NOT NULL, actor TEXT NOT NULL, details TEXT NOT NULL, createdAt INTEGER NOT NULL)")
                db.execSQL("INSERT OR IGNORE INTO audit_events (id, kind, actor, details, createdAt) SELECT id, kind, actor, details, createdAt FROM ownership_audit")
                // automation rules
                db.execSQL("CREATE TABLE IF NOT EXISTS automation_rules (id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, conditionJson TEXT NOT NULL, actionJson TEXT NOT NULL, enabled INTEGER NOT NULL, runCount INTEGER NOT NULL, lastRunAt INTEGER NOT NULL)")
                // saved views
                db.execSQL("CREATE TABLE IF NOT EXISTS saved_views (id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL, scope TEXT NOT NULL, filterJson TEXT NOT NULL, createdAt INTEGER NOT NULL)")
                // message templates (seeded with the default Persian bill)
                db.execSQL("CREATE TABLE IF NOT EXISTS message_templates (id TEXT NOT NULL PRIMARY KEY, title TEXT NOT NULL, body TEXT NOT NULL, createdAt INTEGER NOT NULL)")
                db.execSQL("INSERT OR IGNORE INTO message_templates (id, title, body, createdAt) VALUES ('default', 'صورتحساب ماهانه', 'سلام {name}؛ مصرف این ماه {usage} گیگابایت و مبلغ {amount} تومان است. مانده: {remaining} گیگابایت. مهلت پرداخت: {due_date}. اعتبار: {credits}.', 0)")
            }
        }

        /** The ledger and pending Notifications are permanent data — never migrate destructively. */
        val MIGRATION_4_5 = object : Migration(4, 5) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("CREATE TABLE IF NOT EXISTS pending_package_alerts (`key` TEXT NOT NULL PRIMARY KEY, packageId TEXT NOT NULL, kind TEXT NOT NULL)")
            }
        }

        val MIGRATION_3_4 = object : Migration(3, 4) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("CREATE TABLE IF NOT EXISTS ownership_audit (id TEXT NOT NULL PRIMARY KEY, kind TEXT NOT NULL, effectiveDay INTEGER NOT NULL, actor TEXT NOT NULL, details TEXT NOT NULL, createdAt INTEGER NOT NULL)")
                db.execSQL("CREATE TABLE IF NOT EXISTS suggestion_dismissals (`key` TEXT NOT NULL PRIMARY KEY, mac TEXT NOT NULL, personId TEXT NOT NULL, dismissedAt INTEGER NOT NULL)")
            }
        }

        val MIGRATION_2_3 = object : Migration(2, 3) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL("CREATE TABLE IF NOT EXISTS packages (id TEXT NOT NULL PRIMARY KEY, provider TEXT NOT NULL, subscriber TEXT NOT NULL, type TEXT NOT NULL, routerName TEXT NOT NULL, routerCategory TEXT NOT NULL, window TEXT NOT NULL, quotaGb REAL, remainGb REAL, consumedGb REAL, activation TEXT, expiry TEXT, status TEXT NOT NULL, priority INTEGER NOT NULL, sourceAsOfUnix INTEGER NOT NULL, source TEXT NOT NULL, lastSeenUnix INTEGER NOT NULL, missingSuccessCount INTEGER NOT NULL, unconfirmed INTEGER NOT NULL, archived INTEGER NOT NULL, alias TEXT NOT NULL, color TEXT NOT NULL, localCategory TEXT NOT NULL, visible INTEGER NOT NULL, note TEXT NOT NULL, displayOrder INTEGER NOT NULL, alertsMuted INTEGER NOT NULL, alertThresholdPct INTEGER)")
                db.execSQL("CREATE TABLE IF NOT EXISTS package_snapshots (packageId TEXT NOT NULL, ts INTEGER NOT NULL, quotaGb REAL, remainGb REAL, consumedGb REAL, status TEXT NOT NULL, expiry TEXT, PRIMARY KEY(packageId, ts))")
            }
        }

        val MIGRATION_1_2 = object : Migration(1, 2) {
            override fun migrate(db: SupportSQLiteDatabase) {
                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS persons (" +
                        "id TEXT NOT NULL PRIMARY KEY, name TEXT NOT NULL, " +
                        "`group` TEXT NOT NULL DEFAULT '', colorIndex INTEGER NOT NULL DEFAULT 0, " +
                        "note TEXT NOT NULL DEFAULT '', rateOverride INTEGER, " +
                        "archived INTEGER NOT NULL DEFAULT 0, implicit INTEGER NOT NULL DEFAULT 0)",
                )
                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS device_settings (" +
                        "mac TEXT NOT NULL PRIMARY KEY, ownerPersonId TEXT, alias TEXT NOT NULL DEFAULT '', " +
                        "category TEXT NOT NULL DEFAULT '', note TEXT NOT NULL DEFAULT '', " +
                        "hideFromLedger INTEGER NOT NULL DEFAULT 0, watched INTEGER NOT NULL DEFAULT 0, " +
                        "lastSeenName TEXT NOT NULL DEFAULT '')",
                )
                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS ownership_history (" +
                        "key TEXT NOT NULL PRIMARY KEY, mac TEXT NOT NULL, personId TEXT NOT NULL, " +
                        "sinceDay INTEGER NOT NULL, untilDay INTEGER)",
                )
                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS ledger_months (" +
                        "key TEXT NOT NULL PRIMARY KEY, jYear INTEGER NOT NULL, jMonth INTEGER NOT NULL, " +
                        "globalRate INTEGER NOT NULL, note TEXT NOT NULL DEFAULT '', " +
                        "imported INTEGER NOT NULL DEFAULT 0, closedDay INTEGER)",
                )
                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS ledger_entries (" +
                        "key TEXT NOT NULL PRIMARY KEY, monthKey TEXT NOT NULL, personId TEXT NOT NULL, " +
                        "usageGb REAL NOT NULL DEFAULT 0, rateUsed INTEGER NOT NULL, " +
                        "owedToman INTEGER NOT NULL DEFAULT 0, costOverride INTEGER, " +
                        "paid INTEGER NOT NULL DEFAULT 0, paidToman INTEGER NOT NULL DEFAULT 0, " +
                        "note TEXT NOT NULL DEFAULT '', edited INTEGER NOT NULL DEFAULT 0)",
                )
                db.execSQL(
                    "CREATE TABLE IF NOT EXISTS daily_usage (" +
                        "key TEXT NOT NULL PRIMARY KEY, day INTEGER NOT NULL, mac TEXT NOT NULL, gb REAL NOT NULL)",
                )
            }
        }
    }
}