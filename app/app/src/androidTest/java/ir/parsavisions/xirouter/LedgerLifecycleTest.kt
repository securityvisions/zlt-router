package ir.parsavisions.xirouter

import androidx.room.Room
import androidx.test.core.app.ApplicationProvider
import androidx.test.ext.junit.runners.AndroidJUnit4
import kotlinx.coroutines.runBlocking
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class LedgerLifecycleTest {
    private lateinit var db: AppDb
    private lateinit var store: Store

    @Before
    fun setUp() {
        val context = ApplicationProvider.getApplicationContext<android.content.Context>()
        db = Room.inMemoryDatabaseBuilder(context, AppDb::class.java).build()
        store = Store(context)
        store.defaultRate = 7_700
    }

    @After
    fun tearDown() = db.close()

    @Test
    fun currentMonthMutationCreatesMissingMonthBeforeReconciliation() = runBlocking {
        val day = 100L
        db.personDao().upsert(PersonEntity("person", "شخص"))
        db.deviceDao().upsert(DeviceSettingsEntity("mac"))
        db.ledgerDao().upsertDaily(DailyUsageEntity("$day|mac", day, "mac", 2.0))

        LedgerKeeper.setDeviceOwner(db, store, "mac", "person", day)

        val month = db.ledgerDao().month(monthKey(day))
        assertEquals(store.defaultRate, month?.globalRate)
        assertEquals(2.0, db.ledgerDao().entries(monthKey(day)).single().usageGb, 0.001)
    }

    @Test
    fun ownershipMutationClosesThePreviousOwnershipAndReprojectsTheCurrentMonth() = runBlocking {
        seedCurrentMonth(day = 100, mac = "mac", gb = 2.0)
        db.personDao().upsert(PersonEntity("old", "قدیمی"))
        db.personDao().upsert(PersonEntity("new", "جدید"))
        db.deviceDao().upsert(DeviceSettingsEntity("mac", ownerPersonId = "old"))
        db.ownershipDao().upsert(OwnershipHistoryEntity("old-90", "mac", "old", 90))

        LedgerKeeper.setDeviceOwner(db, store, "mac", "new", 100)

        assertEquals("new", db.deviceDao().byMac("mac")?.ownerPersonId)
        assertEquals(100, db.ownershipDao().forMac("mac").single { it.personId == "old" }.untilDay)
        assertEquals(2.0, db.ledgerDao().entries(monthKey(100)).single { it.personId == "new" }.usageGb, 0.001)
    }

    @Test
    fun archivingAnOldPersonDoesNotCloseANewerPersonsActiveOwnership() = runBlocking {
        db.personDao().upsert(PersonEntity("old", "قدیمی"))
        db.personDao().upsert(PersonEntity("new", "جدید"))
        db.deviceDao().upsert(DeviceSettingsEntity("mac", ownerPersonId = "new"))
        // Preserve the previously possible inconsistent state: both rows are open, while the device points to the newer Person.
        db.ownershipDao().upsert(OwnershipHistoryEntity("old-10", "mac", "old", 10))
        db.ownershipDao().upsert(OwnershipHistoryEntity("new-20", "mac", "new", 20))

        LedgerKeeper.archivePerson(db, store, "old", 30)

        assertTrue(db.personDao().byId("old")!!.archived)
        assertEquals(30, db.ownershipDao().forMac("mac").single { it.personId == "old" }.untilDay)
        assertEquals("new", db.deviceDao().byMac("mac")?.ownerPersonId)
        assertNull(db.ownershipDao().forMac("mac").single { it.personId == "new" }.untilDay)
    }

    @Test
    fun archivingAPersonClearsOnlyTheirActiveDevicesAndReprojectsTheCurrentMonth() = runBlocking {
        seedCurrentMonth(day = 100, mac = "mac", gb = 2.0)
        db.personDao().upsert(PersonEntity("person", "شخص"))
        db.deviceDao().upsert(DeviceSettingsEntity("mac", ownerPersonId = "person"))
        db.ownershipDao().upsert(OwnershipHistoryEntity("owner", "mac", "person", 90))

        LedgerKeeper.archivePerson(db, store, "person", 100)

        assertNull(db.deviceDao().byMac("mac")?.ownerPersonId)
        assertEquals(100, db.ownershipDao().forMac("mac").single().untilDay)
        assertEquals("__unassigned__", db.ledgerDao().entries(monthKey(100)).single().personId)
    }

    @Test
    fun bulkOwnershipUsesOneEffectiveDayAndReconcilesOnceAtomically() = runBlocking {
        seedCurrentMonth(day = 100, mac = "one", gb = 2.0)
        db.ledgerDao().upsertDaily(DailyUsageEntity("100|two", 100, "two", 3.0))
        db.personDao().upsert(PersonEntity("person", "شخص"))
        db.deviceDao().upsert(DeviceSettingsEntity("one"))
        db.deviceDao().upsert(DeviceSettingsEntity("two"))

        LedgerKeeper.bulkDevices(db, store, BulkDeviceChange(setOf("one", "two"), BulkValue.Set("person"), category = "mobile"), 100)

        assertTrue(db.deviceDao().all().all { it.ownerPersonId == "person" && it.category == "mobile" })
        assertTrue(db.ownershipDao().all().all { it.sinceDay == 100L })
        assertEquals(5.0, db.ledgerDao().entries(monthKey(100)).single().usageGb, 0.001)
        assertEquals(1, db.ownershipAuditDao().all().count { it.kind == "bulk" })
    }

    @Test
    fun restoringPersonDoesNotReclaimFormerDevices() = runBlocking {
        db.personDao().upsert(PersonEntity("person", "شخص", archived = true))
        db.deviceDao().upsert(DeviceSettingsEntity("mac", ownerPersonId = null))
        db.ownershipDao().upsert(OwnershipHistoryEntity("past", "mac", "person", 1, 10))

        LedgerKeeper.restorePerson(db, "person", 20)

        assertFalse(db.personDao().byId("person")!!.archived)
        assertNull(db.deviceDao().byMac("mac")!!.ownerPersonId)
        assertEquals(10L, db.ownershipDao().forMac("mac").single().untilDay)
    }

    @Test
    fun hideFromLedgerChangeReprojectsTheCurrentMonth() = runBlocking {
        seedCurrentMonth(day = 100, mac = "mac", gb = 2.0)
        db.personDao().upsert(PersonEntity("person", "شخص"))
        db.deviceDao().upsert(DeviceSettingsEntity("mac", ownerPersonId = "person"))
        db.ownershipDao().upsert(OwnershipHistoryEntity("owner", "mac", "person", 90))
        LedgerKeeper.reconcileMonth(db, store, db.ledgerDao().month(monthKey(100))!!, 90, 100)

        LedgerKeeper.setHideFromLedger(db, store, "mac", true, 100)

        assertTrue(db.deviceDao().byMac("mac")!!.hideFromLedger)
        assertTrue(db.ledgerDao().entries(monthKey(100)).isEmpty())
    }

    @Test
    fun personRateChangeReprojectsOnlyTheCurrentMonth() = runBlocking {
        seedCurrentMonth(day = 100, mac = "mac", gb = 2.0)
        db.personDao().upsert(PersonEntity("person", "شخص"))
        db.deviceDao().upsert(DeviceSettingsEntity("mac", ownerPersonId = "person"))
        db.ownershipDao().upsert(OwnershipHistoryEntity("owner", "mac", "person", 90))
        val closed = LedgerMonthEntity("closed", 1400, 1, 7_000, closedDay = 90)
        db.ledgerDao().upsertMonth(closed)
        db.ledgerDao().upsertEntry(LedgerEntryEntity("closed|person", "closed", "person", 3.0, 7_000, 21_000))
        LedgerKeeper.reconcileMonth(db, store, db.ledgerDao().month(monthKey(100))!!, 90, 100)

        LedgerKeeper.updatePerson(db, store, PersonEntity("person", "شخص", rateOverride = 9_000), 100)

        val current = db.ledgerDao().entries(monthKey(100)).single()
        assertEquals(9_000, current.rateUsed)
        assertEquals(18_000, current.owedToman)
        assertEquals(7_000, db.ledgerDao().entries("closed").single().rateUsed)
        assertFalse(db.personDao().byId("person")!!.archived)
    }

    private suspend fun seedCurrentMonth(day: Long, mac: String, gb: Double) {
        val jalali = jalaliOf(day)
        db.ledgerDao().upsertMonth(LedgerMonthEntity(monthKey(day), jalali.year, jalali.month, 7_700))
        db.ledgerDao().upsertDaily(DailyUsageEntity("$day|$mac", day, mac, gb))
    }

    private fun monthKey(day: Long): String {
        val jalali = jalaliOf(day)
        return MonthAttribution.key(jalali.year, jalali.month)
    }
}
