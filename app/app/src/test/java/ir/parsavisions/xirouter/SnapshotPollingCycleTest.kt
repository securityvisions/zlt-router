package ir.parsavisions.xirouter

import kotlinx.coroutines.async
import kotlinx.coroutines.delay
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class SnapshotPollingCycleTest {
    private val previous = RouterSnapshot(0, true, setOf("old"), 20, 10_000, 0.0, 50.0)
    private val currentStatus = StatusDto(uptime = "1:00", disk = DiskDto(20), proxy = ProxyDto("down"))
    private val currentBalance = BalanceResponse(total_gb = 40.0)
    private val currentClients = ClientsResponse(listOf(ClientDto(mac = "old")))
    private val usage = UsageResponse(rows = listOf(UsageRow(mac = "old", gb = 2.5)))

    @Test
    fun successfulCycleDeliversBeforeAdvancingSnapshotAndBillState() = runBlocking {
        val runtime = FakeRuntime(previousSnapshot = previous, billDate = null)
        val result = SnapshotPollingCycle(runtime).run(SnapshotCycleRequest.Foreground)

        assertEquals(SnapshotCycleOutcome.Success, result.outcome)
        assertEquals(listOf("history", "ledger", "deliver:[ProxyDown, Reboot, BillReady]", "advance"), runtime.effects)
        assertEquals(Snapshots.from(currentStatus, currentBalance, currentClients), runtime.previousSnapshot)
        assertEquals("2026-09-01", runtime.billDate)
        assertEquals(usage, result.routerData?.usage)
    }

    @Test
    fun failedDeliveryRetriesWithoutAdvancingSnapshotOrBillState() = runBlocking {
        val runtime = FakeRuntime(previousSnapshot = previous, billDate = null, deliverySucceeds = false)
        val result = SnapshotPollingCycle(runtime).run(SnapshotCycleRequest.Worker)

        assertEquals(SnapshotCycleOutcome.Retry, result.outcome)
        assertEquals(previous, runtime.previousSnapshot)
        assertNull(runtime.billDate)
        assertEquals(listOf("history", "ledger", "deliver:[ProxyDown, Reboot, BillReady]"), runtime.effects)
    }

    @Test
    fun unrelatedForegroundEndpointFailureDoesNotBlockEssentialCycle() = runBlocking {
        val runtime = FakeRuntime(previousSnapshot = previous, failCost = true)
        val result = SnapshotPollingCycle(runtime).run(SnapshotCycleRequest.Foreground)

        assertEquals(SnapshotCycleOutcome.Success, result.outcome)
        assertNull(result.routerData?.cost)
        assertEquals(usage, result.routerData?.usage)
        assertEquals(Snapshots.from(currentStatus, currentBalance, currentClients), runtime.previousSnapshot)
    }

    @Test
    fun ledgerFailureRetriesButStillDeliversAndAdvancesPublishableSnapshot() = runBlocking {
        val runtime = FakeRuntime(previousSnapshot = previous, billDate = null, failLedger = true)
        val result = SnapshotPollingCycle(runtime).run(SnapshotCycleRequest.Foreground)

        assertEquals(SnapshotCycleOutcome.Retry, result.outcome)
        assertEquals(usage, result.routerData?.usage)
        assertEquals(Snapshots.from(currentStatus, currentBalance, currentClients), runtime.previousSnapshot)
        assertNull(runtime.billDate)
        assertEquals(1, runtime.deliveries)
        assertEquals(listOf("history", "ledger", "deliver:[ProxyDown, Reboot]", "advance"), runtime.effects)
    }

    @Test
    fun failedBillMaintenanceLeavesOnlyBillReadyDueForNextSuccessfulCycle() = runBlocking {
        val runtime = FakeRuntime(previousSnapshot = previous, billDate = null, failLedger = true)
        val cycle = SnapshotPollingCycle(runtime)

        cycle.run(SnapshotCycleRequest.Worker)
        runtime.failLedger = false
        val retry = cycle.run(SnapshotCycleRequest.Worker)

        assertEquals(SnapshotCycleOutcome.Success, retry.outcome)
        assertEquals("2026-09-01", runtime.billDate)
        assertEquals(
            listOf("deliver:[ProxyDown, Reboot]", "deliver:[BillReady]"),
            runtime.effects.filter { it.startsWith("deliver:") },
        )
    }

    @Test
    fun localHistoryFailureAlsoDoesNotBlockNotificationState() = runBlocking {
        val runtime = FakeRuntime(previousSnapshot = previous, failHistory = true)

        val result = SnapshotPollingCycle(runtime).run(SnapshotCycleRequest.Worker)

        assertEquals(SnapshotCycleOutcome.Retry, result.outcome)
        assertEquals(1, runtime.deliveries)
        assertEquals(Snapshots.from(currentStatus, currentBalance, currentClients), runtime.previousSnapshot)
    }

    @Test
    fun firstSnapshotBaselinesSilentlyIncludingBillReady() = runBlocking {
        val runtime = FakeRuntime(previousSnapshot = null, billDate = null)

        val result = SnapshotPollingCycle(runtime).run(SnapshotCycleRequest.Worker)

        assertEquals(SnapshotCycleOutcome.Success, result.outcome)
        assertEquals(0, runtime.deliveries)
        assertEquals(listOf("history", "ledger", "advance"), runtime.effects)
        assertEquals("2026-09-01", runtime.billDate)
    }

    @Test
    fun deliveryExceptionRetriesWithoutEscapingOrAdvancing() = runBlocking {
        val runtime = FakeRuntime(previousSnapshot = previous, throwDelivery = true)

        val result = SnapshotPollingCycle(runtime).run(SnapshotCycleRequest.Worker)

        assertEquals(SnapshotCycleOutcome.Retry, result.outcome)
        assertEquals(previous, runtime.previousSnapshot)
        assertEquals(1, runtime.deliveries)
    }

    @Test
    fun failedBaselineCommitRetriesAfterSuccessfulDelivery() = runBlocking {
        val runtime = FakeRuntime(previousSnapshot = previous, billDate = null, advanceSucceeds = false)

        val result = SnapshotPollingCycle(runtime).run(SnapshotCycleRequest.Worker)

        assertEquals(SnapshotCycleOutcome.Retry, result.outcome)
        assertEquals(previous, runtime.previousSnapshot)
        assertNull(runtime.billDate)
    }

    @Test
    fun concurrentAdaptersSerializeDiffDeliverySoNotificationIsNotDuplicated() = runBlocking {
        val runtime = FakeRuntime(previousSnapshot = previous, deliveryDelayMs = 50)
        val cycle = SnapshotPollingCycle(runtime)

        val first = async { cycle.run(SnapshotCycleRequest.Foreground) }
        val second = async { cycle.run(SnapshotCycleRequest.Worker) }
        first.await()
        second.await()

        assertEquals(1, runtime.deliveries)
        assertEquals(Snapshots.from(currentStatus, currentBalance, currentClients), runtime.previousSnapshot)
    }

    private inner class FakeRuntime(
        override var previousSnapshot: RouterSnapshot?,
        override var billDate: String? = "2026-08-01",
        private val deliverySucceeds: Boolean = true,
        private val failCost: Boolean = false,
        var failLedger: Boolean = false,
        private val failHistory: Boolean = false,
        private val throwDelivery: Boolean = false,
        private val advanceSucceeds: Boolean = true,
        private val deliveryDelayMs: Long = 0,
    ) : SnapshotCycleRuntime {
        val effects = mutableListOf<String>()
        var deliveries = 0

        override val nowMillis: Long get() = 1_777_852_800_000L
        override val today: String get() = "2026-09-01"
        override suspend fun status() = currentStatus
        override suspend fun usageToday() = usage
        override suspend fun usageMonth() = UsageResponse("month")
        override suspend fun cost(): CostResponse = if (failCost) error("cost unavailable") else CostResponse()
        override suspend fun bill() = BillResponse()
        override suspend fun balance() = currentBalance
        override suspend fun clients() = currentClients
        override suspend fun devices() = DevicesResponse()
        override suspend fun historyUsage() = HistoryResponse("usage")
        override suspend fun historyBalance() = HistoryResponse("balance")
        override suspend fun recordLocalHistory(balanceGb: Double?, usageTodayGb: Double) {
            effects += "history"
            if (failHistory) error("history unavailable")
        }
        override suspend fun syncLedgerDevices(devices: DevicesResponse, usage: UsageResponse) {}
        override suspend fun recordLedgerDaily(usage: UsageResponse) {
            effects += "ledger"
            if (failLedger) error("ledger unavailable")
        }
        override suspend fun ensureLedgerMonth() {}
        override suspend fun importLedgerHistory() = true
        override suspend fun deliver(events: List<AlertEvent>): NotificationDeliveryOutcome {
            deliveries++
            effects += "deliver:$events"
            delay(deliveryDelayMs)
            if (throwDelivery) error("notification manager failed")
            return if (deliverySucceeds) NotificationDeliveryOutcome.Delivered else NotificationDeliveryOutcome.Error
        }
        override fun advance(snapshot: RouterSnapshot, billDate: String?): Boolean {
            effects += "advance"
            if (!advanceSucceeds) return false
            previousSnapshot = snapshot
            this.billDate = billDate
            return true
        }
    }
}
