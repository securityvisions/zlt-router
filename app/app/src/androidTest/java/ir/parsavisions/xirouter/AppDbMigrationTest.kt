package ir.parsavisions.xirouter

import android.database.Cursor
import androidx.room.Room
import androidx.room.testing.MigrationTestHelper
import androidx.sqlite.db.SupportSQLiteDatabase
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Rule
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class AppDbMigrationTest {
    private val databaseName = "migration-test"

    @get:Rule
    val helper = MigrationTestHelper(
        InstrumentationRegistry.getInstrumentation(),
        AppDb::class.java,
    )

    @After
    fun cleanUp() {
        ApplicationProvider.getApplicationContext<android.content.Context>()
            .deleteDatabase(databaseName)
    }

    @Test
    fun migrationFromV1PreservesSamplesAndCreatesTheCurrentLedgerSchema() {
        helper.createDatabase(databaseName, 1).apply {
            execSQL("INSERT INTO samples (ts, kind, value) VALUES (1001, 'balance', 12.5)")
            execSQL("INSERT INTO samples (ts, kind, value) VALUES (1002, 'usage_today', 3.25)")
            close()
        }

        helper.runMigrationsAndValidate(databaseName, 5, true, AppDb.MIGRATION_1_2, AppDb.MIGRATION_2_3, AppDb.MIGRATION_3_4, AppDb.MIGRATION_4_5).use { db ->
            assertSchema(db)
            db.query("SELECT ts, kind, value FROM samples ORDER BY ts").use { cursor ->
                assertTrue(cursor.moveToFirst())
                assertEquals(1001L, cursor.getLong(0))
                assertEquals("balance", cursor.getString(1))
                assertEquals(12.5, cursor.getDouble(2), 0.0)
                assertTrue(cursor.moveToNext())
                assertEquals(1002L, cursor.getLong(0))
                assertEquals("usage_today", cursor.getString(1))
                assertEquals(3.25, cursor.getDouble(2), 0.0)
                assertTrue(!cursor.moveToNext())
            }
        }

        val db = Room.databaseBuilder(
            ApplicationProvider.getApplicationContext(),
            AppDb::class.java,
            databaseName,
        ).addMigrations(AppDb.MIGRATION_1_2, AppDb.MIGRATION_2_3, AppDb.MIGRATION_3_4, AppDb.MIGRATION_4_5).build()
        try {
            runBlocking {
                assertEquals(SampleEntity(1001, "balance", 12.5), db.sampleDao().latest("balance"))
                db.personDao().upsert(PersonEntity("person", "Person"))
                db.deviceDao().upsert(DeviceSettingsEntity("aa:bb:cc:dd:ee:ff", ownerPersonId = "person"))
                db.ownershipDao().upsert(OwnershipHistoryEntity("owner", "aa:bb:cc:dd:ee:ff", "person", 10))
                db.ledgerDao().upsertMonth(LedgerMonthEntity("1405/05", 1405, 5, 7_700))
                db.ledgerDao().upsertEntry(LedgerEntryEntity("entry", "1405/05", "person", rateUsed = 7_700))
                db.ledgerDao().upsertDaily(DailyUsageEntity("10|aa", 10, "aa:bb:cc:dd:ee:ff", 1.5))
                assertEquals(1, db.personDao().all().size)
                assertEquals(1, db.deviceDao().all().size)
                assertEquals(1, db.ownershipDao().all().size)
                assertEquals(1, db.ledgerDao().allMonths().size)
                assertEquals(1, db.ledgerDao().allEntries().size)
                assertEquals(1, db.ledgerDao().daysBetween(10, 10).size)
            }
        } finally {
            db.close()
        }
    }

    @Test
    fun migrationFromV2CreatesPackageStoreAndPreservesLedger() {
        helper.createDatabase(databaseName, 2).apply {
            execSQL("INSERT INTO persons (id,name,`group`,colorIndex,note,archived,implicit) VALUES ('p','Person','',0,'',0,0)")
            close()
        }
        helper.runMigrationsAndValidate(databaseName, 5, true, AppDb.MIGRATION_2_3, AppDb.MIGRATION_3_4, AppDb.MIGRATION_4_5).use { db ->
            db.query("SELECT name FROM persons WHERE id='p'").use { assertTrue(it.moveToFirst()); assertEquals("Person", it.getString(0)) }
            db.query("PRAGMA table_info(`packages`)").use { assertTrue(it.columnNames().containsAll(setOf("id", "quotaGb", "alias", "missingSuccessCount", "alertsMuted"))) }
            db.query("PRAGMA table_info(`package_snapshots`)").use { assertTrue(it.columnNames().containsAll(setOf("packageId", "ts", "remainGb"))) }
            db.query("PRAGMA table_info(`pending_package_alerts`)").use { assertEquals(setOf("key", "packageId", "kind"), it.columnNames()) }
        }
    }

    @Test
    fun migrationFromV5SeedsPaymentsCopiesAuditAndPreservesLedger() {
        helper.createDatabase(databaseName, 5).apply {
            execSQL("INSERT INTO persons (id,name,`group`,colorIndex,note,archived,implicit) VALUES ('p','Person','',0,'',0,0)")
            execSQL("INSERT INTO ledger_months (key,jYear,jMonth,globalRate,note,imported) VALUES ('1405/05',1405,5,7700,'',0)")
            execSQL("INSERT INTO ledger_entries (key,monthKey,personId,usageGb,rateUsed,owedToman,paid,paidToman,note,edited) VALUES ('e1','1405/05','p',10.0,7700,77000,1,50000,'',0)")
            execSQL("INSERT INTO ownership_audit (id,kind,effectiveDay,actor,details,createdAt) VALUES ('a1','ownership',14050101,'local','p->mac',100)")
            close()
        }
        helper.runMigrationsAndValidate(databaseName, 6, true, AppDb.MIGRATION_5_6).use { db ->
            db.query("PRAGMA table_info(`persons`)").use {
                assertTrue(it.columnNames().containsAll(setOf("creditToman", "quotaGb")))
            }
            db.query("PRAGMA table_info(`device_settings`)").use {
                assertTrue(it.columnNames().containsAll(setOf("ip", "deviceType", "tags", "lastSeenUnix", "excludeFromAnalytics")))
            }
            db.query("SELECT personId, monthKey, amountToman FROM payments").use {
                assertTrue(it.moveToFirst()); assertEquals("p", it.getString(0))
                assertEquals("1405/05", it.getString(1)); assertEquals(50000L, it.getLong(2))
            }
            db.query("SELECT kind, details FROM audit_events").use {
                assertTrue(it.moveToFirst()); assertEquals("ownership", it.getString(0))
            }
            db.query("SELECT key, paidToman FROM ledger_entries").use {
                assertTrue(it.moveToFirst()); assertEquals("e1", it.getString(0)); assertEquals(50000L, it.getLong(1))
            }
            db.query("SELECT id FROM message_templates").use {
                assertTrue(it.moveToFirst()); assertEquals("default", it.getString(0))
            }
        }
    }

    private fun assertSchema(db: SupportSQLiteDatabase) {
        val expected = mapOf(
            "samples" to setOf("ts", "kind", "value"),
            "persons" to setOf("id", "name", "group", "colorIndex", "note", "rateOverride", "archived", "implicit"),
            "device_settings" to setOf("mac", "ownerPersonId", "alias", "category", "note", "hideFromLedger", "watched", "lastSeenName"),
            "ownership_history" to setOf("key", "mac", "personId", "sinceDay", "untilDay"),
            "ledger_months" to setOf("key", "jYear", "jMonth", "globalRate", "note", "imported", "closedDay"),
            "ledger_entries" to setOf("key", "monthKey", "personId", "usageGb", "rateUsed", "owedToman", "costOverride", "paid", "paidToman", "note", "edited"),
            "daily_usage" to setOf("key", "day", "mac", "gb"),
            "ownership_audit" to setOf("id", "kind", "effectiveDay", "actor", "details", "createdAt"),
            "suggestion_dismissals" to setOf("key", "mac", "personId", "dismissedAt"),
            "packages" to setOf("id", "provider", "subscriber", "type", "routerName", "routerCategory", "window", "quotaGb", "remainGb", "consumedGb", "activation", "expiry", "status", "priority", "sourceAsOfUnix", "source", "lastSeenUnix", "missingSuccessCount", "unconfirmed", "archived", "alias", "color", "localCategory", "visible", "note", "displayOrder", "alertsMuted", "alertThresholdPct"),
            "package_snapshots" to setOf("packageId", "ts", "quotaGb", "remainGb", "consumedGb", "status", "expiry"),
            "pending_package_alerts" to setOf("key", "packageId", "kind"),
        )
        expected.forEach { (table, columns) ->
            db.query("PRAGMA table_info(`$table`)").use { cursor ->
                assertEquals("columns in $table", columns, cursor.columnNames())
            }
        }
    }

    private fun Cursor.columnNames(): Set<String> {
        val nameIndex = getColumnIndexOrThrow("name")
        return buildSet {
            while (moveToNext()) add(getString(nameIndex))
        }
    }
}
