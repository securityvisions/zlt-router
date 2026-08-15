package ir.parsavisions.xirouter

import android.content.Context
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/** Android boundary for the polling cycle's Router API, Room, Store, and Notification operations. */
class AndroidSnapshotCycleRuntime(context: Context) : SnapshotCycleRuntime {
    private val appContext = context.applicationContext
    private val store = Store(appContext)
    private val db = AppDb.get(appContext)
    private val base get() = store.baseUrl
    private val token get() = store.token

    override val nowMillis: Long get() = System.currentTimeMillis()
    override val today: String get() = SimpleDateFormat("yyyy-MM-dd", Locale.US).format(Date(nowMillis))
    override var previousSnapshot: RouterSnapshot?
        get() = store.lastSnapshot?.let { runCatching { ApiClient.json.decodeFromString<RouterSnapshot>(it) }.getOrNull() }
        set(value) { store.lastSnapshot = value?.let { ApiClient.json.encodeToString(it) } }
    override var billDate: String?
        get() = store.lastBillNotifDate
        set(value) { store.lastBillNotifDate = value }

    override suspend fun status(): StatusDto = ApiClient.get(base, token, "/status")
    override suspend fun usageToday(): UsageResponse = ApiClient.get(base, token, "/usage", "period" to "today")
    override suspend fun usageMonth(): UsageResponse = ApiClient.get(base, token, "/usage", "period" to "month")
    override suspend fun cost(): CostResponse = ApiClient.get(base, token, "/cost")
    override suspend fun bill(): BillResponse = ApiClient.get(base, token, "/bill")
    override suspend fun balance(): BalanceResponse = ApiClient.get<BalanceResponse>(base, token, "/balance").also {
        PackageIngestion(appContext).ingest(it)
    }
    override suspend fun clients(): ClientsResponse = ApiClient.get(base, token, "/clients")
    override suspend fun devices(): DevicesResponse = ApiClient.get(base, token, "/devices")
    override suspend fun historyUsage(): HistoryResponse =
        ApiClient.get(base, token, "/history", "kind" to "usage", "days" to "30")
    override suspend fun historyBalance(): HistoryResponse =
        ApiClient.get(base, token, "/history", "kind" to "balance", "days" to "90")

    override suspend fun recordLocalHistory(balanceGb: Double?, usageTodayGb: Double) {
        val dao = db.sampleDao()
        // Monotonic allocation makes the legacy timestamp-only primary key practical across rapid/parallel polls.
        val baseTs = maxOf(nowMillis, (dao.latestTimestamp() ?: Long.MIN_VALUE) + 1)
        balanceGb?.let { dao.insert(SampleEntity(baseTs, "balance", it)) }
        if (usageTodayGb > 0) dao.insert(SampleEntity(baseTs + 1, "usage_today", usageTodayGb))
        dao.prune(nowMillis - 365L * 86_400_000L)
    }

    override suspend fun syncLedgerDevices(devices: DevicesResponse, usage: UsageResponse) =
        LedgerKeeper.syncDevices(db, devices, usage)
    override suspend fun recordLedgerDaily(usage: UsageResponse) = LedgerKeeper.recordDaily(db, usage)
    override suspend fun ensureLedgerMonth() = LedgerKeeper.ensureMonthly(db, store)
    override suspend fun importLedgerHistory() = LedgerKeeper.importRouterHistory(db, store, base, token)

    override suspend fun deliver(events: List<AlertEvent>): NotificationDeliveryOutcome = Notifier.post(appContext, events, store)

    override fun advance(snapshot: RouterSnapshot, billDate: String?): Boolean {
        // One synchronous preference transaction prevents observers seeing only half the baseline.
        return store.advanceNotificationBaseline(ApiClient.json.encodeToString(snapshot), billDate)
    }
}
