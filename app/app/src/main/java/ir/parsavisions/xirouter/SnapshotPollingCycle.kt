package ir.parsavisions.xirouter

import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

/** Which adapter requested a polling cycle. Foreground additionally loads every published Router API domain. */
enum class SnapshotCycleRequest { Foreground, Worker }

enum class SnapshotCycleOutcome { Success, Retry }

data class SnapshotRouterData(
    val status: StatusDto,
    val usage: UsageResponse,
    val usageMonth: UsageResponse? = null,
    val cost: CostResponse? = null,
    val bill: BillResponse? = null,
    val balance: BalanceResponse,
    val clients: ClientsResponse,
    val devices: DevicesResponse? = null,
    val historyUsage: HistoryResponse? = null,
    val historyBalance: HistoryResponse? = null,
)

data class SnapshotCycleResult(
    val outcome: SnapshotCycleOutcome,
    val routerData: SnapshotRouterData? = null,
    val failure: Throwable? = null,
)

/**
 * The cycle's platform seam. Android adapters supply Router API, Room, Store, and Notification details;
 * this module owns their ordering and advancement semantics.
 */
interface SnapshotCycleRuntime {
    val nowMillis: Long
    val today: String
    var previousSnapshot: RouterSnapshot?
    var billDate: String?

    suspend fun status(): StatusDto
    suspend fun usageToday(): UsageResponse
    suspend fun usageMonth(): UsageResponse
    suspend fun cost(): CostResponse
    suspend fun bill(): BillResponse
    suspend fun balance(): BalanceResponse
    suspend fun clients(): ClientsResponse
    suspend fun devices(): DevicesResponse
    suspend fun historyUsage(): HistoryResponse
    suspend fun historyBalance(): HistoryResponse

    suspend fun recordLocalHistory(balanceGb: Double?, usageTodayGb: Double)
    suspend fun syncLedgerDevices(devices: DevicesResponse, usage: UsageResponse)
    suspend fun recordLedgerDaily(usage: UsageResponse)
    suspend fun ensureLedgerMonth()
    suspend fun importLedgerHistory(): Boolean
    suspend fun deliver(events: List<AlertEvent>): NotificationDeliveryOutcome
    fun advance(snapshot: RouterSnapshot, billDate: String?): Boolean
}

/**
 * One serialized Snapshot polling cycle shared by foreground and WorkManager adapters.
 * State is advanced only after every due Notification has been delivered successfully.
 */
class SnapshotPollingCycle(private val runtime: SnapshotCycleRuntime) {
    suspend fun run(request: SnapshotCycleRequest): SnapshotCycleResult = processMutex.withLock {
        var usage: UsageResponse? = null
        var status: StatusDto? = null
        var balance: BalanceResponse? = null
        var clients: ClientsResponse? = null
        var devices: DevicesResponse? = null
        var failure: Throwable? = null

        fun failed(error: Throwable) {
            if (failure == null) failure = error
        }

        try { usage = runtime.usageToday() } catch (e: Exception) { e.rethrowCancellation(); failed(e) }
        try { status = runtime.status() } catch (e: Exception) { e.rethrowCancellation(); failed(e) }
        try { balance = runtime.balance() } catch (e: Exception) { e.rethrowCancellation(); failed(e) }
        try { clients = runtime.clients() } catch (e: Exception) { e.rethrowCancellation(); failed(e) }
        try { devices = runtime.devices() } catch (e: Exception) { e.rethrowCancellation() /* usage still sustains the Ledger */ }

        val usageValue = usage
        var ledgerSucceeded = usageValue != null
        if (usageValue != null) {
            try { runtime.recordLocalHistory(balance?.aggregate()?.remain_gb ?: balance?.total_gb, usageValue.rows.sumOf { it.gb }) } catch (e: Exception) { e.rethrowCancellation(); failed(e) }
            suspend fun maintainLedger(block: suspend () -> Unit) {
                try { block() } catch (e: Exception) {
                    e.rethrowCancellation()
                    ledgerSucceeded = false
                    failed(e)
                }
            }
            if (devices != null) maintainLedger { runtime.syncLedgerDevices(devices, usageValue) }
            maintainLedger { runtime.recordLedgerDaily(usageValue) }
            maintainLedger { runtime.ensureLedgerMonth() }
            maintainLedger { check(runtime.importLedgerHistory()) { "Router history import incomplete" } }
        }

        var usageMonth: UsageResponse? = null
        var cost: CostResponse? = null
        var bill: BillResponse? = null
        var historyUsage: HistoryResponse? = null
        var historyBalance: HistoryResponse? = null
        if (request == SnapshotCycleRequest.Foreground) {
            try { usageMonth = runtime.usageMonth() } catch (e: Exception) { e.rethrowCancellation() }
            try { cost = runtime.cost() } catch (e: Exception) { e.rethrowCancellation() }
            try { bill = runtime.bill() } catch (e: Exception) { e.rethrowCancellation() }
            try { historyUsage = runtime.historyUsage() } catch (e: Exception) { e.rethrowCancellation() }
            try { historyBalance = runtime.historyBalance() } catch (e: Exception) { e.rethrowCancellation() }
        }

        val statusValue = status
        val balanceValue = balance
        val clientsValue = clients
        if (usageValue == null || statusValue == null || balanceValue == null || clientsValue == null) {
            return@withLock SnapshotCycleResult(SnapshotCycleOutcome.Retry, failure = failure)
        }

        val data = SnapshotRouterData(
            statusValue, usageValue, usageMonth, cost, bill, balanceValue, clientsValue,
            devices, historyUsage, historyBalance,
        )
        val snapshot = Snapshots.from(statusValue, balanceValue, clientsValue)
        val previous = runtime.previousSnapshot
        // The first Snapshot establishes both baselines silently; BillReady is also a diff event.
        val billDue = BillReady.due(runtime.today, runtime.billDate)
        val events = NotificationEvents.events(previous, snapshot).toMutableList()
        val billReady = previous != null && billDue && ledgerSucceeded
        if (billReady) events += AlertEvent.BillReady
        val delivery = try {
            if (events.isEmpty()) NotificationDeliveryOutcome.Disabled else runtime.deliver(events)
        } catch (e: Exception) {
            e.rethrowCancellation()
            failed(e)
            NotificationDeliveryOutcome.Error
        }
        if (notificationCycleOutcome(delivery) == NotificationCycleDecision.Retry) {
            return@withLock SnapshotCycleResult(SnapshotCycleOutcome.Retry, data, failure)
        }
        val advanced = try {
            // A failed Ledger run must not claim the bill was recorded. Snapshot diffs still advance,
            // preventing their successful Notifications from being duplicated while BillReady stays due.
            runtime.advance(snapshot, runtime.today.takeIf { billDue && ledgerSucceeded } ?: runtime.billDate)
        } catch (e: Exception) {
            e.rethrowCancellation()
            failed(e)
            false
        }
        if (!advanced) return@withLock SnapshotCycleResult(SnapshotCycleOutcome.Retry, data, failure)
        SnapshotCycleResult(
            if (failure == null) SnapshotCycleOutcome.Success else SnapshotCycleOutcome.Retry,
            data,
            failure,
        )
    }

    private fun Exception.rethrowCancellation() {
        if (this is CancellationException) throw this
    }

    private companion object {
        /** Store's read-diff-deliver-write transaction is process-wide, across both adapters. */
        val processMutex = Mutex()
    }
}
