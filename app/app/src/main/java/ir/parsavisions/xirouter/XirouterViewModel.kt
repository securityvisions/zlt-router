package ir.parsavisions.xirouter

import android.app.Application
import androidx.compose.runtime.mutableStateOf
import androidx.lifecycle.AndroidViewModel
import androidx.lifecycle.viewModelScope
import androidx.room.withTransaction
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.util.UUID

/**
 * Central controller: the router-API state cache, the Room-backed billing ledger,
 * the ownership model with its suggestion engine, and all user actions.
 */
class XirouterViewModel(app: Application) : AndroidViewModel(app) {
    val store = Store(app)
    private val db = AppDb.get(app)

    // ── Router state (one cache per domain) ──────────────────────────────────
    val status = mutableStateOf<StatusDto?>(null)
    val usage = mutableStateOf<UsageResponse?>(null)
    val usageMonth = mutableStateOf<UsageResponse?>(null)
    val cost = mutableStateOf<CostResponse?>(null)
    val bill = mutableStateOf<BillResponse?>(null)
    val balance = mutableStateOf<BalanceResponse?>(null)
    val clients = mutableStateOf<ClientsResponse?>(null)
    val devicesApi = mutableStateOf<DevicesResponse?>(null)
    val live = mutableStateOf<LiveResponse?>(null)
    val link = mutableStateOf<LinkDto?>(null)
    val historyUsage = mutableStateOf<HistoryResponse?>(null)
    val historyBalance = mutableStateOf<HistoryResponse?>(null)

    val error = mutableStateOf<String?>(null)
    val loading = mutableStateOf(false)
    val lastUpdate = mutableStateOf(0L)
    val balanceLoading = mutableStateOf(false)
    val balanceError = mutableStateOf<String?>(null)

    /** Incrementing this applies all appearance preferences without recreating the Activity. */
    val appearanceRevision = mutableStateOf(0)

    // ── Ledger reactive state ────────────────────────────────────────────────
    val nav = ir.parsavisions.xirouter.ui.XirouterNav()

    val persons: StateFlow<List<PersonEntity>> =
        db.personDao().allFlow().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val devices: StateFlow<List<DeviceSettingsEntity>> =
        db.deviceDao().allFlow().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val months: StateFlow<List<LedgerMonthEntity>> =
        db.ledgerDao().monthsFlow().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val ownership: StateFlow<List<OwnershipHistoryEntity>> =
        db.ownershipDao().allFlow().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val packages: StateFlow<List<PackageEntity>> =
        db.packageDao().allFlow().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val localBalanceSamples: StateFlow<List<SampleEntity>> =
        db.sampleDao().betweenFlow("balance", System.currentTimeMillis() - 90L * 86_400_000L)
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val localUsageSamples: StateFlow<List<SampleEntity>> =
        db.sampleDao().betweenFlow("usage_today", System.currentTimeMillis() - 30L * 86_400_000L)
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val entriesByMonth: StateFlow<Map<String, List<LedgerEntryEntity>>> =
        db.ledgerDao().allEntriesFlow()
            .map { it.groupBy { e -> e.monthKey } }
            .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyMap())

    // ── v2 reactive state (inbox / activity / automations) ──────────────────
    val inboxEvents: StateFlow<List<InboxEventEntity>> =
        db.inboxDao().allFlow().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val activityEvents: StateFlow<List<ActivityEventEntity>> =
        db.activityDao().allFlow().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
    val automationRules: StateFlow<List<AutomationRuleEntity>> =
        db.automationDao().allFlow().stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

    private var automationPrevFired = mutableMapOf<String, Boolean>()
    private var quotaPrevLevels = mutableMapOf<String, String>()

    private val base get() = store.baseUrl
    private val token get() = store.token

    fun configured(): Boolean = store.configured()

    init {
        nav.tab(ir.parsavisions.xirouter.ui.tabRoute(store.landingTab))
        refreshAll()
    }

    // ── Refresh ──────────────────────────────────────────────────────────────

    fun refreshAll() {
        if (loading.value) return
        loading.value = true
        error.value = null
        viewModelScope.launch {
            try {
                val result = withContext(Dispatchers.IO) {
                    SnapshotPollingCycle(AndroidSnapshotCycleRuntime(getApplication())).run(SnapshotCycleRequest.Foreground)
                }
                val r = result.routerData
                if (r != null) {
                    status.value = r.status
                    usage.value = r.usage
                    r.usageMonth?.let { usageMonth.value = it }
                    r.cost?.let { cost.value = it }
                    r.bill?.let { bill.value = it }
                    balance.value = r.balance
                    clients.value = r.clients
                    r.devices?.let { devicesApi.value = it }
                    r.historyUsage?.let { historyUsage.value = it }
                    r.historyBalance?.let { historyBalance.value = it }
                    lastUpdate.value = System.currentTimeMillis()
                }
                refreshLink()
                runV2Poll()
                if (result.outcome == SnapshotCycleOutcome.Retry) {
                    throw result.failure ?: IllegalStateException("Snapshot polling cycle incomplete")
                }
            } catch (e: Exception) {
                e.rethrowIfCancellation()
                error.value = friendlyError(e)
            } finally {
                loading.value = false
            }
        }
    }

    fun refreshStatus() = viewModelScope.launch { try { status.value = withContext(Dispatchers.IO) { ApiClient.get<StatusDto>(base, token, "/status") } } catch (e: Exception) { e.rethrowIfCancellation(); error.value = friendlyError(e) } }
    fun refreshUsage() = viewModelScope.launch { try { usage.value = withContext(Dispatchers.IO) { ApiClient.get<UsageResponse>(base, token, "/usage", "period" to "today") } } catch (e: Exception) { e.rethrowIfCancellation(); error.value = friendlyError(e) } }
    fun refreshUsageMonth() = viewModelScope.launch { try { usageMonth.value = withContext(Dispatchers.IO) { ApiClient.get<UsageResponse>(base, token, "/usage", "period" to "month") } } catch (e: Exception) { e.rethrowIfCancellation(); error.value = friendlyError(e) } }
    fun refreshCost() = viewModelScope.launch { try { cost.value = withContext(Dispatchers.IO) { ApiClient.get<CostResponse>(base, token, "/cost") } } catch (e: Exception) { e.rethrowIfCancellation(); error.value = friendlyError(e) } }
    fun refreshBill() = viewModelScope.launch { try { bill.value = withContext(Dispatchers.IO) { ApiClient.get<BillResponse>(base, token, "/bill") } } catch (e: Exception) { e.rethrowIfCancellation(); error.value = friendlyError(e) } }
    fun refreshBalance() {
        if (balanceLoading.value) return
        balanceLoading.value = true
        balanceError.value = null
        viewModelScope.launch {
            try {
                balance.value = withContext(Dispatchers.IO) {
                    ApiClient.get<BalanceResponse>(base, token, "/balance").also { PackageIngestion(getApplication()).ingest(it) }
                }
            } catch (e: Exception) {
                e.rethrowIfCancellation()
                balanceError.value = friendlyError(e)
            } finally {
                balanceLoading.value = false
            }
        }
    }
    fun refreshClients() = viewModelScope.launch { try { clients.value = withContext(Dispatchers.IO) { ApiClient.get<ClientsResponse>(base, token, "/clients") } } catch (e: Exception) { e.rethrowIfCancellation(); error.value = friendlyError(e) } }
    fun refreshLink() = viewModelScope.launch { try { link.value = withContext(Dispatchers.IO) { ApiClient.get<LinkDto>(base, token, "/link") } } catch (e: Exception) { e.rethrowIfCancellation() } }
    fun refreshHistory() = viewModelScope.launch { try {
        val (u, b) = withContext(Dispatchers.IO) {
            Pair(
                ApiClient.get<HistoryResponse>(base, token, "/history", "kind" to "usage", "days" to "30"),
                ApiClient.get<HistoryResponse>(base, token, "/history", "kind" to "balance", "days" to "90"),
            )
        }
        historyUsage.value = u; historyBalance.value = b
    } catch (e: Exception) { e.rethrowIfCancellation(); error.value = friendlyError(e) } }

    /** Await a live sample (the Live screen polls ~1.5 s without stacking). */
    suspend fun fetchLive(): LiveResponse =
        withContext(Dispatchers.IO) { ApiClient.get<LiveResponse>(base, token, "/live") }

    // ── Payment & cost edits ─────────────────────────────────────────────────

    /** Save every editable field together, using the Room entity's real key (including import keys). */
    fun updateLedgerEntry(entryKey: String, costOverride: Long?, paidToman: Long, note: String) = viewModelScope.launch {
        withContext(Dispatchers.IO) {
            db.withTransaction {
                val entry = db.ledgerDao().allEntries().find { it.key == entryKey } ?: return@withTransaction
                val owed = costOverride ?: Pricing.owedToman(entry.usageGb, entry.rateUsed)
                val payment = paidToman.coerceAtLeast(0)
                db.ledgerDao().updateManualFields(
                    key = entry.key,
                    owed = owed,
                    costOverride = costOverride,
                    paid = payment >= owed && owed > 0,
                    paidToman = payment,
                    note = note.trim(),
                )
            }
        }
    }

    fun setMonthNote(monthKey: String, note: String) = viewModelScope.launch {
        withContext(Dispatchers.IO) {
            db.ledgerDao().month(monthKey)?.let { db.ledgerDao().upsertMonth(it.copy(note = note)) }
        }
    }

    // ── Person CRUD ──────────────────────────────────────────────────────────

    fun addPerson(name: String, group: String = "") = viewModelScope.launch {
        if (name.isBlank()) return@launch
        db.personDao().upsert(
            PersonEntity(
                id = "p-" + UUID.randomUUID().toString().take(8),
                name = name.trim(), group = group.trim(),
            ),
        )
    }

    fun updatePerson(person: PersonEntity) = viewModelScope.launch {
        withContext(Dispatchers.IO) {
            LedgerKeeper.updatePerson(db, store, person, tehranDay(System.currentTimeMillis()))
        }
    }

    fun deletePerson(personId: String) = viewModelScope.launch {
        withContext(Dispatchers.IO) {
            LedgerKeeper.archivePerson(db, store, personId, tehranDay(System.currentTimeMillis()))
        }
    }

    fun restorePerson(personId: String) = viewModelScope.launch(Dispatchers.IO) {
        LedgerKeeper.restorePerson(db, personId, tehranDay(System.currentTimeMillis()))
    }

    fun bulkDevices(change: BulkDeviceChange) = viewModelScope.launch(Dispatchers.IO) {
        LedgerKeeper.bulkDevices(db, store, change, tehranDay(System.currentTimeMillis()))
    }

    suspend fun previewCorrection(request: OwnershipCorrectionRequest): OwnershipCorrectionPlan = withContext(Dispatchers.IO) {
        val today = tehranDay(System.currentTimeMillis())
        OwnershipPlanning.correction(request, db.ownershipDao().forMac(request.mac).map { OwnershipRange(it.mac, it.personId, it.sinceDay, it.untilDay) }, db.ledgerDao().daysBetween(request.startDay, request.endDay?.minus(1) ?: today).map { it.day }, today)
    }

    fun applyCorrection(request: OwnershipCorrectionRequest, onDone: (Result<OwnershipCorrectionPlan>) -> Unit = {}) = viewModelScope.launch {
        val result = try { Result.success(withContext(Dispatchers.IO) { LedgerKeeper.applyOwnershipCorrection(db, store, request, tehranDay(System.currentTimeMillis())) }) }
        catch (e: Exception) { e.rethrowIfCancellation(); Result.failure(e) }
        onDone(result)
    }

    suspend fun previewMerge(request: PersonMergeRequest): PersonMergePlan = withContext(Dispatchers.IO) {
        PersonMergePlanning.preview(request, db.deviceDao().all(), db.ownershipDao().all(), db.ledgerDao().allEntries())
    }

    fun applyMerge(request: PersonMergeRequest, onDone: (Result<PersonMergePlan>) -> Unit = {}) = viewModelScope.launch {
        val result = try { Result.success(withContext(Dispatchers.IO) { LedgerKeeper.mergePersons(db, store, request, tehranDay(System.currentTimeMillis())) }) }
        catch (e: Exception) { e.rethrowIfCancellation(); Result.failure(e) }
        onDone(result)
    }

    // ── Device / ownership edits ─────────────────────────────────────────────

    fun setDeviceOwner(mac: String, personId: String?) = viewModelScope.launch {
        withContext(Dispatchers.IO) {
            LedgerKeeper.setDeviceOwner(db, store, mac, personId, tehranDay(System.currentTimeMillis()))
        }
    }

    fun setDeviceAlias(mac: String, alias: String) = viewModelScope.launch {
        withContext(Dispatchers.IO) {
            val dev = db.deviceDao().byMac(mac) ?: DeviceSettingsEntity(mac = mac)
            db.deviceDao().upsert(dev.copy(alias = alias.trim()))
        }
    }

    fun setDeviceNote(mac: String, note: String) = viewModelScope.launch { withContext(Dispatchers.IO) { val d = db.deviceDao().byMac(mac) ?: DeviceSettingsEntity(mac); db.deviceDao().upsert(d.copy(note = note)) } }
    fun setDeviceCategory(mac: String, category: String) = viewModelScope.launch { withContext(Dispatchers.IO) { val d = db.deviceDao().byMac(mac) ?: DeviceSettingsEntity(mac); db.deviceDao().upsert(d.copy(category = category)) } }
    fun setHideFromLedger(mac: String, hide: Boolean) = viewModelScope.launch {
        withContext(Dispatchers.IO) {
            LedgerKeeper.setHideFromLedger(db, store, mac, hide, tehranDay(System.currentTimeMillis()))
        }
    }

    fun updatePackageMetadata(value: PackageEntity) = viewModelScope.launch(Dispatchers.IO) {
        val current = db.packageDao().byId(value.id) ?: return@launch
        // Router-owned amount/provider/lifecycle fields always come from the current Room row.
        db.packageDao().upsert(current.copy(alias = value.alias.trim(), color = value.color.trim(),
            localCategory = value.localCategory.trim(), visible = value.visible, note = value.note.trim(),
            displayOrder = value.displayOrder, alertsMuted = value.alertsMuted,
            alertThresholdPct = value.alertThresholdPct?.coerceIn(1, 100)))
    }

    fun movePackage(id: String, direction: Int) = viewModelScope.launch(Dispatchers.IO) {
        db.withTransaction {
            val rows = db.packageDao().all().filterNot { it.archived }.sortedWith(compareBy<PackageEntity> { it.displayOrder }.thenBy { it.priority }.thenBy { it.id }).toMutableList()
            val from = rows.indexOfFirst { it.id == id }; val to = (from + direction).coerceIn(0, rows.lastIndex)
            if (from >= 0 && from != to) { rows.add(to, rows.removeAt(from)); rows.forEachIndexed { index, row -> db.packageDao().upsert(row.copy(displayOrder = index)) } }
        }
    }

    suspend fun packageSnapshots(id: String) = withContext(Dispatchers.IO) { db.packageDao().snapshots(id) }

    fun setWatch(mac: String, on: Boolean) = viewModelScope.launch {
        try {
            withContext(Dispatchers.IO) {
                ApiClient.post<OkResponse>(base, token, "/device/watch", mapOf("mac" to mac, "on" to on))
                val d = db.deviceDao().byMac(mac) ?: DeviceSettingsEntity(mac)
                db.deviceDao().upsert(d.copy(watched = on))
            }
        } catch (e: Exception) { e.rethrowIfCancellation(); error.value = friendlyError(e) }
    }

    fun renameDevice(mac: String, name: String) = viewModelScope.launch {
        try {
            withContext(Dispatchers.IO) {
                ApiClient.post<OkResponse>(base, token, "/device/rename", mapOf("mac" to mac, "name" to name))
                val d = db.deviceDao().byMac(mac) ?: DeviceSettingsEntity(mac)
                db.deviceDao().upsert(d.copy(alias = name, lastSeenName = name))
            }
            refreshClients()
        } catch (e: Exception) { e.rethrowIfCancellation(); error.value = friendlyError(e) }
    }

    // ── Owner suggestions ────────────────────────────────────────────────────

    /** Deterministic scoring for one device, fed by Room + the app's daily data. */
    suspend fun suggestionsFor(mac: String): List<OwnerSuggestion> {
        val device = db.deviceDao().byMac(mac) ?: return emptyList()
        val personList = db.personDao().editable()
        val history = db.ownershipDao().forMac(mac).map { it.personId }
        val allOwners = db.deviceDao().all().associate { it.mac to it.ownerPersonId }
        val activityCtx = computeActivity(device.mac)
        val deviceName = device.alias.ifBlank { device.lastSeenName }
        val dismissed = db.ownershipAuditDao().dismissals().filter { it.mac == mac }.mapTo(mutableSetOf()) { it.personId }
        return SuggestionScorer.score(
            device.mac, deviceName,
            SuggestionContext(
                persons = personList.map { it.id to it.name },
                historyOfMac = { history },
                activeOwner = { allOwners[it] },
                ouiShareCount = { m, p ->
                    allOwners.count { (mac, owner) -> owner == p && mac != m && SuggestionScorer.oui(mac) == SuggestionScorer.oui(m) }
                },
                activityScore = { m, p -> activityCtx[p] ?: 0f },
            ),
        ).filterNot { it.personId in dismissed }
    }

    fun dismissSuggestion(mac: String, personId: String) = viewModelScope.launch(Dispatchers.IO) {
        db.ownershipAuditDao().dismiss(SuggestionDismissalEntity("$mac|$personId", mac, personId))
    }

    fun undoDismissSuggestion(mac: String, personId: String) = viewModelScope.launch(Dispatchers.IO) {
        db.ownershipAuditDao().undoDismissal("$mac|$personId")
    }

    /** Fraction of recent days where this device and the person's other devices were both active. */
    private suspend fun computeActivity(mac: String): Map<String, Float> {
        val today = tehranDay(System.currentTimeMillis())
        val days = db.ledgerDao().daysBetween(today - 60, today).groupBy { it.day }
        if (days.isEmpty()) return emptyMap()
        val owners = db.deviceDao().all().associate { it.mac to it.ownerPersonId }
        val devUsed: MutableMap<String, Long> = mutableMapOf()
        val personActive: MutableMap<String, MutableSet<Long>> = mutableMapOf()
        val macUsage: Map<Long, Set<String>> = days.mapValues { (_, rows) ->
            rows.filter { it.gb > 0.02 }.map { it.mac }.toSet()
        }
        macUsage.forEach { (day, macs) ->
            if (mac in macs) devUsed[mac] = devUsed.getOrDefault(mac, 0) + 1
            macs.forEach { m ->
                val p = owners[m]
                if (p != null && m != mac) {
                    personActive.getOrPut(p) { mutableSetOf() }.add(day)
                }
            }
        }
        // per person: count the device's active days that the person's other devices also used
        val result = mutableMapOf<String, Float>()
        personActive.forEach { (p, daysSet) ->
            val devDays = devUsed[mac] ?: return@forEach
            if (devDays == 0L) return@forEach
            val deviceDaysSet = macUsage.filterValues { mac in it }.keys
            val both = deviceDaysSet.count { it in daysSet }
            result[p] = (both.toFloat() / devDays).coerceIn(0f, 1f)
        }
        return result
    }

    fun applySuggestion(mac: String, personId: String) = setDeviceOwner(mac, personId)

    fun applySuggestions(assignments: Map<String, String>) = viewModelScope.launch(Dispatchers.IO) {
        LedgerKeeper.assignOwners(db, store, assignments, tehranDay(System.currentTimeMillis()))
    }

    // ── CSV export ───────────────────────────────────────────────────────────

    /** One line per person of a month; Western digits so spreadsheets digest it. */
    suspend fun monthCsv(monthKey: String): String {
        val month = db.ledgerDao().month(monthKey) ?: return ""
        return ledgerReadModel(listOf(month), db.ledgerDao().entries(monthKey)).monthCsv(monthKey)
    }

    /** Every month of a Jalali year, one line per person, plus a totals footer. */
    suspend fun yearCsv(year: Int): String {
        val yearMonths = db.ledgerDao().monthsFlow().first { true }.filter { it.jYear == year }
        return ledgerReadModel(yearMonths, db.ledgerDao().yearEntries(year)).yearCsv(year)
    }

    private suspend fun ledgerReadModel(
        ledgerMonths: List<LedgerMonthEntity>,
        entries: List<LedgerEntryEntity>,
    ) = ledgerReadModel(db.personDao().all(), ledgerMonths, entries)

    // ── Router actions ───────────────────────────────────────────────────────

    fun setDefaultRate(rate: Long) = viewModelScope.launch {
        store.defaultRate = rate
        withContext(Dispatchers.IO) { LedgerKeeper.ensureMonthly(db, store) }
    }

    fun updateAppearance(change: Store.() -> Unit) {
        store.change()
        appearanceRevision.value++
    }

    fun setLandingTab(tab: String) { store.landingTab = tab }

    fun testUrl(url: String, onResult: (String) -> Unit) = viewModelScope.launch {
        try {
            val r = withContext(Dispatchers.IO) { ApiClient.post<OkResponse>(base, token, "/test", mapOf("url" to url)) }
            onResult(r.result ?: "unreachable")
        } catch (e: Exception) { e.rethrowIfCancellation(); onResult(friendlyError(e)) }
    }

    fun switchProxy(node: String, onDone: (Boolean) -> Unit) = viewModelScope.launch {
        try {
            withContext(Dispatchers.IO) { ApiClient.post<OkResponse>(base, token, "/proxy/switch", mapOf("node" to node)) }
            onDone(true); refreshStatus()
        } catch (e: Exception) { e.rethrowIfCancellation(); error.value = friendlyError(e); onDone(false) }
    }

    fun reboot(onDone: (Boolean) -> Unit) = viewModelScope.launch {
        try {
            withContext(Dispatchers.IO) { ApiClient.post<OkResponse>(base, token, "/reboot", emptyMap()) }
            onDone(true)
        } catch (e: Exception) { e.rethrowIfCancellation(); error.value = friendlyError(e); onDone(false) }
    }

    fun friendlyError(e: Exception): String = when (e) {
        is UnauthorizedException -> "توکن اشتباه است"
        is UnreachableException -> "روتر در دسترس نیست"
        is ApiException -> "خطای HTTP ${e.status}"
        else -> e.message ?: "خطا"
    }

    // ── v2 actions (payments, automation, inbox, saved views, templates) ─────

    private suspend fun runV2Poll() {
        try {
            withContext(Dispatchers.IO) {
                val fired = V2Keepers.runAutomation(db, automationContext(), automationPrevFired)
                automationPrevFired.clear(); automationPrevFired.putAll(fired)
                quotaPrevLevels = V2Keepers.runQuotaCheck(db, quotaPrevLevels, System.currentTimeMillis()).toMutableMap()
                V2Keepers.pruneActivity(db)
            }
        } catch (e: Exception) {
            e.rethrowIfCancellation()
        }
    }

    private suspend fun automationContext(): AutomationContext = withContext(Dispatchers.IO) {
        val main = balance.value?.main
        val persons = db.personDao().all()
        val entries = db.ledgerDao().allEntries()
        val unpaid = entries.count { PaymentMath.billTotal(it) > it.paidToman }
        val quotaUsed = persons.maxOfOrNull { p ->
            val used = entries.filter { it.personId == p.id }.sumOf { it.usageGb }
            p.quotaGb?.let { used / it * 100 } ?: 0.0
        }
        AutomationContext(
            packageRemainPct = main?.remain?.div(main.quota?.toDouble() ?: 1.0)?.times(100.0),
            quotaUsedPct = quotaUsed?.takeIf { it > 0 },
            proxyUp = status.value?.proxy?.state == "up",
            unpaidPeople = unpaid,
            offlineDevices = 0,
        )
    }

    fun addPayment(personId: String, monthKey: String, amountToman: Long, atMillis: Long, method: String, note: String, onDone: () -> Unit = {}) =
        viewModelScope.launch(Dispatchers.IO) {
            V2Keepers.recordPayment(db, personId, monthKey, amountToman, atMillis, method, note)
            V2Keepers.applyCreditToBills(db, personId)
            onDone()
        }

    fun saveAutomation(name: String, conditionJson: String, actionJson: String, onDone: () -> Unit = {}) =
        viewModelScope.launch(Dispatchers.IO) {
            db.automationDao().upsert(
                AutomationRuleEntity(
                    id = "rule-" + UUID.randomUUID().toString().take(8),
                    name = name.trim(), conditionJson = conditionJson, actionJson = actionJson,
                ),
            )
            onDone()
        }

    fun toggleAutomation(id: String, enabled: Boolean) = viewModelScope.launch(Dispatchers.IO) {
        db.automationDao().setEnabled(id, enabled)
    }

    fun deleteAutomation(id: String) = viewModelScope.launch(Dispatchers.IO) {
        db.automationDao().delete(id)
    }

    fun saveView(title: String, scope: String, filterJson: String) = viewModelScope.launch(Dispatchers.IO) {
        db.savedViewDao().upsert(
            SavedViewEntity(
                id = "view-" + UUID.randomUUID().toString().take(8),
                title = title.trim(), scope = scope, filterJson = filterJson,
            ),
        )
    }

    fun deleteView(id: String) = viewModelScope.launch(Dispatchers.IO) {
        db.savedViewDao().delete(id)
    }

    suspend fun viewsFor(scope: String) = withContext(Dispatchers.IO) { db.savedViewDao().forScope(scope) }

    suspend fun templates() = withContext(Dispatchers.IO) { db.messageTemplateDao().all() }

    fun saveTemplate(id: String, title: String, body: String) = viewModelScope.launch(Dispatchers.IO) {
        db.messageTemplateDao().upsert(
            MessageTemplateEntity(
                id = id.ifBlank { "tpl-" + UUID.randomUUID().toString().take(8) },
                title = title.trim(), body = body,
            ),
        )
    }

    fun deleteTemplate(id: String) = viewModelScope.launch(Dispatchers.IO) {
        db.messageTemplateDao().delete(id)
    }

    suspend fun renderTemplate(template: MessageTemplateEntity, vars: Map<String, String>): String =
        MessageCenter.render(template.body, vars)

    fun markInbox(id: String, state: String) = viewModelScope.launch(Dispatchers.IO) {
        db.inboxDao().setState(id, state)
    }

    /** Dashboard v2: the forecast + insights block, computed from live state. */
    fun dashboardForecast(): String {
        val main = balance.value?.main ?: return "—"
        val usageToday = usage.value?.rows?.sumOf { it.gb } ?: 0.0
        val elapsed = java.time.LocalDate.now().dayOfMonth
        val days = java.time.YearMonth.now().lengthOfMonth()
        val projected = Forecasting.projectUsage(usageToday, elapsed, days)
        val rate = 7700L
        return "${Format.gbValue(projected)} GB ≈ ${Format.faDigits("${Forecasting.projectCost(projected, rate)}")} تومان"
    }

    fun dashboardInsights(): List<String> {
        val main = balance.value?.main
        val usageToday = usage.value?.rows?.sumOf { it.gb } ?: 0.0
        val people = persons.value
        val entries = entriesByMonth.value.values.flatten()
        val topPerson = people.mapNotNull { p ->
            entries.filter { it.personId == p.id }.sumOf { it.usageGb }.takeIf { it > 0 }?.let { "${p.name} (${Format.gbValue(it)} GB)" }
        }.maxByOrNull { it }
        val exhaustion = main?.remain?.let { r -> Forecasting.packageExhaustionDays(r, 0.5) }
        val base = Insights.generate(
            usageTodayGb = usageToday,
            prevMonthTotalGb = null,
            topPersonGb = null,
            packageExhaustionDays = exhaustion,
            spendTodayToman = 0,
            avgSpendToman = 0,
            newDeviceCount = 0,
        ).toMutableList()
        topPerson?.let { base += "بیشترین مصرف امروز: $it" }
        return base.map { if (it.isBlank()) it else "«برآورد» $it" }
    }
}