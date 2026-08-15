package ir.parsavisions.xirouter.ui

import android.content.Context
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.Delete
import androidx.compose.material.icons.filled.Edit
import androidx.compose.material.icons.filled.Lightbulb
import androidx.compose.material.icons.filled.PersonAdd
import androidx.compose.material.icons.filled.PersonOff
import androidx.compose.material.icons.automirrored.filled.ReceiptLong
import androidx.compose.material.icons.filled.Save
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Share
import androidx.compose.material.icons.filled.Star
import androidx.compose.material.icons.filled.Tune
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ir.parsavisions.xirouter.Format
import ir.parsavisions.xirouter.LedgerEntryEntity
import ir.parsavisions.xirouter.LedgerMonthEntity
import ir.parsavisions.xirouter.LedgerMonthQuery
import ir.parsavisions.xirouter.LedgerPaymentFilter
import ir.parsavisions.xirouter.LedgerPaymentStatus
import ir.parsavisions.xirouter.LedgerReadEntry
import ir.parsavisions.xirouter.LedgerReadModel
import ir.parsavisions.xirouter.LedgerReadMonth
import ir.parsavisions.xirouter.LedgerReadPerson
import ir.parsavisions.xirouter.LedgerRowSort
import ir.parsavisions.xirouter.MonthAttribution
import ir.parsavisions.xirouter.MergeManualChoice
import ir.parsavisions.xirouter.OwnershipCorrectionPlan
import ir.parsavisions.xirouter.OwnershipCorrectionRequest
import ir.parsavisions.xirouter.PersonMergePlan
import ir.parsavisions.xirouter.PersonMergeRequest
import ir.parsavisions.xirouter.PersonEntity
import ir.parsavisions.xirouter.Pricing
import ir.parsavisions.xirouter.SuggestionConfidence
import ir.parsavisions.xirouter.SuggestionSignal
import ir.parsavisions.xirouter.confidence
import ir.parsavisions.xirouter.cancellationAwareResult
import ir.parsavisions.xirouter.XirouterViewModel
import ir.parsavisions.xirouter.jalaliMonthLabel
import ir.parsavisions.xirouter.jalaliMonthKeyLabel
import ir.parsavisions.xirouter.ledgerReadModel
import ir.parsavisions.xirouter.jalaliOf
import ir.parsavisions.xirouter.jalaliDay
import ir.parsavisions.xirouter.tehranDay
import kotlinx.coroutines.launch
import zed.rainxch.rikkaui.components.ui.alertdialog.AlertDialog
import zed.rainxch.rikkaui.components.ui.alertdialog.AlertDialogHeader
import zed.rainxch.rikkaui.components.ui.button.Button
import zed.rainxch.rikkaui.components.ui.button.ButtonVariant
import zed.rainxch.rikkaui.components.ui.card.Card
import zed.rainxch.rikkaui.components.ui.checkbox.Checkbox
import zed.rainxch.rikkaui.components.ui.icon.Icon
import zed.rainxch.rikkaui.components.ui.button.IconButton
import zed.rainxch.rikkaui.components.ui.input.Input
import zed.rainxch.rikkaui.components.ui.select.Select
import zed.rainxch.rikkaui.components.ui.select.SelectOption
import zed.rainxch.rikkaui.components.ui.text.Text
import zed.rainxch.rikkaui.components.ui.text.TextVariant
import zed.rainxch.rikkaui.components.ui.toast.LocalToastHostState
import zed.rainxch.rikkaui.foundation.RikkaTheme

// ── Ledger tab: people first, one Jalali month at a time ─────────────────────

private val LedgerRowSort.label get() = when (this) {
    LedgerRowSort.NAME -> "نام"
    LedgerRowSort.USAGE -> "مصرف"
    LedgerRowSort.OWED -> "بدهی"
    LedgerRowSort.UNPAID -> "باقیمانده"
}
private val paymentOptions = listOf(
    SelectOption("all", "همهٔ پرداختها"), SelectOption("paid", "تسویهشده"),
    SelectOption("partial", "پرداخت جزئی"), SelectOption("unpaid", "پرداختنشده"),
)

@Composable
fun LedgerScreen(vm: XirouterViewModel) {
    val today = jalaliOf(tehranDay(System.currentTimeMillis()))
    val months by vm.months.collectAsStateWithLifecycle()
    val entriesByMonth by vm.entriesByMonth.collectAsStateWithLifecycle()
    val personRows by vm.persons.collectAsStateWithLifecycle()
    var selKey by remember { mutableStateOf(MonthAttribution.key(today.year, today.month)) }
    LaunchedEffect(months) {
        if (selKey !in months.map { it.key } && months.isNotEmpty()) {
            selKey = months.first().key
        }
    }
    var query by remember { mutableStateOf("") }
    var personFilter by remember { mutableStateOf("all") }
    var groupFilter by remember { mutableStateOf("all") }
    var paymentFilter by remember { mutableStateOf("all") }
    var sort by remember { mutableStateOf(LedgerRowSort.OWED) }
    var hidePaid by remember { mutableStateOf(false) }
    var hideUnbilled by remember { mutableStateOf(false) }
    var showDetails by remember { mutableStateOf(vm.store.ledgerDetailColumns) }
    var editingEntry by remember { mutableStateOf<LedgerEntryEntity?>(null) }
    val month = months.find { it.key == selKey }
    val entries = entriesByMonth[selKey].orEmpty()
    val persons = personRows.associateBy { it.id }
    val readModel = ledgerReadModel(personRows, months, entriesByMonth.values.flatten())
    val projection = readModel.month(
        selKey,
        LedgerMonthQuery(
            query = query,
            personId = personFilter.takeUnless { it == "all" },
            group = groupFilter.takeUnless { it == "all" },
            payment = LedgerPaymentFilter.valueOf(paymentFilter.uppercase()),
            hidePaid = hidePaid,
            hideUnbilled = hideUnbilled,
            sort = sort,
        ),
    )
    val summary = projection.summary
    val groups = projection.groups
    val entriesByKey = entries.associateBy { it.key }
    val visibleEntries = projection.rows.mapNotNull { entriesByKey[it.key] }

    LazyColumn(Modifier.fillMaxWidth()) {
        item {
            Row(
                Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = RikkaTheme.spacing.sm),
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Select(
                    selectedValue = selKey,
                    onValueChange = { selKey = it },
                    options = months.map { SelectOption(it.key, jalaliMonthLabel(it.jYear, it.jMonth)) },
                    modifier = Modifier.weight(1f),
                )
            }
        }
        item {
            BoxWithConstraints(Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg)) {
                val stacked = maxWidth < 340.dp || LocalDensity.current.fontScale > 1.2f
                if (stacked) Column {
                    StatCard("مصرف", "${Format.gbValue(summary.usageGb)} GB", Modifier.fillMaxWidth())
                    StatCard("بدهی / وصول", "${Format.faCompact(summary.owed.toDouble())} / ${Format.faCompact(summary.collected.toDouble())}", Modifier.fillMaxWidth())
                    StatCard("باقیمانده", Format.faCompact(summary.unpaid.toDouble()), Modifier.fillMaxWidth(), if (summary.unpaid > 0) StatusColors.down else StatusColors.up)
                } else Column {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        StatCard("مصرف", "${Format.gbValue(summary.usageGb)} GB", Modifier.weight(1f))
                        StatCard("بدهی", Format.faCompact(summary.owed.toDouble()), Modifier.weight(1f))
                    }
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        StatCard("وصول", Format.faCompact(summary.collected.toDouble()), Modifier.weight(1f), StatusColors.up)
                        StatCard("باقیمانده", Format.faCompact(summary.unpaid.toDouble()), Modifier.weight(1f), if (summary.unpaid > 0) StatusColors.down else StatusColors.up)
                    }
                }
            }
        }
        item {
            Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text("درصد وصول", variant = TextVariant.Muted, modifier = Modifier.weight(1f))
                    FigureText("${Format.pctCompact((summary.collectionRate * 100).toInt())}", variant = TextVariant.P, style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold))
                }
                Spacer(Modifier.height(6.dp))
                val rate = summary.collectionRate
                zed.rainxch.rikkaui.components.ui.progress.Progress(
                    progress = rate,
                    height = 8.dp,
                    fillColor = if (rate >= 0.99f) StatusColors.up else if (rate >= 0.5f) StatusColors.warning else StatusColors.down,
                )
            }
        }
        item {
            BoxWithConstraints(Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = RikkaTheme.spacing.sm)) {
                val stacked = maxWidth < 340.dp || LocalDensity.current.fontScale > 1.2f
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = { vm.nav.push(XRoute.YearReport(month?.jYear ?: today.year)) }, variant = ButtonVariant.Secondary, modifier = Modifier.weight(1f)) { Text("گزارش سال") }
                        Button(onClick = { vm.nav.push(XRoute.People) }, variant = ButtonVariant.Secondary, modifier = Modifier.weight(1f)) { Text("افراد") }
                    }
                    if (stacked) {
                        Button(onClick = { vm.nav.push(XRoute.Suggestions) }, variant = ButtonVariant.Ghost, modifier = Modifier.fillMaxWidth()) { Text("پیشنهاد مالکیت") }
                        Button(onClick = { vm.nav.push(XRoute.OwnershipCorrection()) }, variant = ButtonVariant.Ghost, modifier = Modifier.fillMaxWidth()) { Text("اصلاح مالکیت تاریخی") }
                        ExportMonthButton(vm, selKey, month?.jYear ?: today.year, Modifier.fillMaxWidth())
                    } else Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Button(onClick = { vm.nav.push(XRoute.Suggestions) }, variant = ButtonVariant.Ghost, modifier = Modifier.weight(1f)) { Text("پیشنهاد مالکیت") }
                        ExportMonthButton(vm, selKey, month?.jYear ?: today.year, Modifier.weight(1f))
                    }
                    if (!stacked) Button(onClick = { vm.nav.push(XRoute.OwnershipCorrection()) }, variant = ButtonVariant.Ghost, modifier = Modifier.fillMaxWidth()) { Text("اصلاح مالکیت تاریخی") }
                }
            }
        }
        item { SectionTitle("افراد") }
        item {
            BoxWithConstraints(Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg)) {
                val stacked = maxWidth < 360.dp || LocalDensity.current.fontScale > 1.15f
                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                    Input(query, { query = it }, Modifier.fillMaxWidth(), placeholder = "جستوجوی نام، گروه یا یادداشت", leadingIcon = Icons.Filled.Search, clearable = true)
                    if (stacked) {
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Select(personFilter, { personFilter = it }, listOf(SelectOption("all", "همه افراد")) + entries.mapNotNull { persons[it.personId] }.distinctBy { it.id }.map { SelectOption(it.id, it.name) }, Modifier.weight(1f), label = "فیلتر شخص")
                            Select(groupFilter, { groupFilter = it }, listOf(SelectOption("all", "همه گروهها")) + groups.map { SelectOption(it, it) }, Modifier.weight(1f), label = "فیلتر گروه")
                        }
                        Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                            Select(paymentFilter, { paymentFilter = it }, paymentOptions, Modifier.weight(1f), label = "فیلتر پرداخت")
                            Select(sort.name, { sort = LedgerRowSort.valueOf(it) }, LedgerRowSort.entries.map { SelectOption(it.name, "مرتبسازی: ${it.label}") }, Modifier.weight(1f), label = "مرتبسازی")
                        }
                    } else Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                        Select(personFilter, { personFilter = it }, listOf(SelectOption("all", "همه افراد")) + entries.mapNotNull { persons[it.personId] }.distinctBy { it.id }.map { SelectOption(it.id, it.name) }, Modifier.weight(1f), label = "فیلتر شخص")
                        Select(groupFilter, { groupFilter = it }, listOf(SelectOption("all", "همه گروهها")) + groups.map { SelectOption(it, it) }, Modifier.weight(1f), label = "فیلتر گروه")
                        Select(paymentFilter, { paymentFilter = it }, paymentOptions, Modifier.weight(1f), label = "فیلتر پرداخت")
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        if (!stacked) Select(sort.name, { sort = LedgerRowSort.valueOf(it) }, LedgerRowSort.entries.map { SelectOption(it.name, "مرتبسازی: ${it.label}") }, Modifier.weight(1f), label = "مرتبسازی")
                        Checkbox(hidePaid, { hidePaid = it }, label = "پنهانکردن تسویهشدهها", modifier = Modifier.weight(1f))
                    }
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Checkbox(hideUnbilled, { hideUnbilled = it }, label = "پنهانکردن بدون مالک", modifier = Modifier.weight(1f))
                        Checkbox(showDetails, { showDetails = it; vm.store.ledgerDetailColumns = it }, label = "نمایش جزئیات", modifier = Modifier.weight(1f))
                    }
                    Text("${Format.faNum(visibleEntries.size.toString())} ردیف از ${Format.faNum(projection.allRowCount.toString())}", variant = TextVariant.Muted)
                }
            }
        }
        if (entries.isEmpty()) {
            item {
                EmptyState(
                    Icons.AutoMirrored.Filled.ReceiptLong,
                    "این ماه هنوز ردیفی ندارد",
                    "مصرف هر فرد پس از پایان ماه و یا با واردات از روتر ثبت می‌شود.",
                    modifier = Modifier.padding(horizontal = RikkaTheme.spacing.lg),
                )
            }
        } else if (visibleEntries.isEmpty()) {
            item { EmptyState(Icons.Filled.Search, "نتیجهای پیدا نشد", "فیلترها یا عبارت جستوجو را تغییر دهید.", Modifier.padding(horizontal = RikkaTheme.spacing.lg)) }
        } else {
            items(visibleEntries, key = { it.key }) { entry ->
                val person = persons[entry.personId]
                val unpaid = projection.rows.first { it.key == entry.key }.amounts.unpaid
                Card(
                    modifier = Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp),
                    onClick = { vm.nav.push(ir.parsavisions.xirouter.ui.XRoute.Person(entry.personId)) },
                ) {
                    Row(
                        Modifier.padding(RikkaTheme.spacing.md),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        PersonAvatar(person?.name ?: "؟", person?.colorIndex ?: 0, size = 36)
                        Spacer(Modifier.width(RikkaTheme.spacing.md))
                        Column(Modifier.weight(1f)) {
                            Text(person?.name ?: "بدون مالک", variant = TextVariant.P, style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold))
                            if (showDetails) Text(
                                "${Format.gbValue(entry.usageGb)} GB · بدهی ${Format.faCompact(entry.owedToman.toDouble())}",
                                variant = TextVariant.Muted,
                            )
                            if (showDetails && entry.note.isNotBlank()) Text(entry.note, variant = TextVariant.Small)
                        }
                        Column(horizontalAlignment = Alignment.End) {
                            IconButton(Icons.Filled.Tune, "ویرایش پرداخت، هزینه و یادداشت", onClick = { editingEntry = entry })
                            if (unpaid > 0) {
                                Text("باقی: ${Format.faCompact(unpaid.toDouble())}", variant = TextVariant.Muted, color = StatusColors.down)
                            } else {
                                Text(Format.faCompact(entry.paidToman.toDouble()) + " وصول", variant = TextVariant.Muted, color = StatusColors.up)
                            }
                        }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
    editingEntry?.let { LedgerEntryEditDialog(vm, it) { editingEntry = null } }
}

@Composable
private fun LedgerEntryEditDialog(vm: XirouterViewModel, entry: LedgerEntryEntity, onClose: () -> Unit) {
    var payment by remember { mutableStateOf(entry.paidToman.toString()) }
    var cost by remember { mutableStateOf(entry.costOverride?.toString().orEmpty()) }
    var note by remember { mutableStateOf(entry.note) }
    AlertDialog(
        open = true,
        onDismiss = onClose,
        onConfirm = {
            val paid = (Format.parseAmount(payment) ?: 0.0).toLong().coerceAtLeast(0)
            val override = cost.takeIf(String::isNotBlank)?.let { (Format.parseAmount(it) ?: 0.0).toLong().coerceAtLeast(0) }
            vm.updateLedgerEntry(entry.key, override, paid, note)
            onClose()
        },
        content = {
            AlertDialogHeader("ویرایش ردیف دفترحساب", description = "پرداخت جزئی مجاز است. هزینهٔ دستی خالی یعنی محاسبه با نرخ.")
            Input(payment, { payment = it }, Modifier.padding(top = 8.dp), placeholder = "مبلغ پرداختی (تومان)", label = "مبلغ پرداختی", keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), visualTransformation = Format.GroupedNumber)
            Input(cost, { cost = it }, Modifier.padding(top = 8.dp), placeholder = "هزینهٔ دستی (اختیاری)", label = "هزینهٔ دستی", keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), visualTransformation = Format.GroupedNumber, clearable = true)
            Input(note, { note = it }, Modifier.padding(top = 8.dp), placeholder = "یادداشت ردیف", label = "یادداشت", singleLine = false)
        },
    )
}

@Composable
private fun StatCard(label: String, value: String, modifier: Modifier = Modifier, tint: androidx.compose.ui.graphics.Color = RikkaTheme.colors.onBackground) {
    Card(modifier.padding(vertical = 4.dp)) {
        Column(Modifier.padding(RikkaTheme.spacing.md)) {
            Text(label, variant = TextVariant.Muted)
            FigureText(value, variant = TextVariant.H4, style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold), color = tint)
        }
    }
}

@Composable
private fun ExportMonthButton(vm: XirouterViewModel, monthKey: String, fallbackYear: Int, modifier: Modifier = Modifier) {
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val toast = LocalToastHostState.current
    val launcher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri ->
        if (uri != null) {
            scope.launch {
                val text = vm.monthCsv(monthKey)
                val ok = Export.writeCsv(context, uri, text)
                toast.show(if (ok) "خروجی ماه ذخیره شد" else "خروجی نوشته نشد")
            }
        }
    }
    Button(onClick = {
        scope.launch { launcher.launch("xirouter-${monthKey.replace("/", "-")}.csv") }
    }, variant = ButtonVariant.Secondary, modifier = modifier) { Text("خروجی CSV") }
}

// ── Person detail ────────────────────────────────────────────────────────────

@Composable
fun PersonDetail(vm: XirouterViewModel, personId: String) {
    val personRows by vm.persons.collectAsStateWithLifecycle()
    val entriesByMonth by vm.entriesByMonth.collectAsStateWithLifecycle()
    val devices by vm.devices.collectAsStateWithLifecycle()
    val ownership by vm.ownership.collectAsStateWithLifecycle()
    val persons = personRows.associateBy { it.id }
    val person = persons[personId]
    val allEntries = entriesByMonth.values.flatten()
    val history = ledgerReadModel(personRows, emptyList(), allEntries).personHistory(personId)
    val entriesByKey = allEntries.associateBy { it.key }
    val myEntries = history.mapNotNull { entriesByKey[it.key] }
    val myDevices = devices.filter { it.ownerPersonId == personId }
    var editing by remember { mutableStateOf(false) }
    var paying by remember { mutableStateOf<LedgerEntryEntity?>(null) }
    var removingDevice by remember { mutableStateOf<ir.parsavisions.xirouter.DeviceSettingsEntity?>(null) }

    LazyColumn(Modifier.fillMaxWidth()) {
        if (person == null) {
            item { EmptyState(Icons.Filled.PersonOff, "فرد یافت نشد", "", modifier = Modifier.padding(24.dp)) }
            return@LazyColumn
        }
        item {
            Card(Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg)) {
                Row(Modifier.padding(RikkaTheme.spacing.lg), verticalAlignment = Alignment.CenterVertically) {
                    PersonAvatar(person.name, person.colorIndex, size = 52)
                    Spacer(Modifier.width(RikkaTheme.spacing.md))
                    Column(Modifier.weight(1f)) {
                        Text(person.name, variant = TextVariant.H3)
                        Text(listOfNotNull(person.group.takeIf { it.isNotBlank() }, person.note.takeIf { it.isNotBlank() }).joinToString(" · "), variant = TextVariant.Muted)
                    }
                    if (!person.archived) {
                        IconButton(icon = Icons.Filled.Edit, contentDescription = "ویرایش", onClick = { editing = true })
                    } else {
                        Button(onClick = { vm.restorePerson(person.id) }, variant = ButtonVariant.Secondary) { Text("بازیابی") }
                    }
                }
            }
        }
        item {
            SectionTitle("دستگاهها (${myDevices.size})")
            if (!person.archived) Column(Modifier.padding(horizontal = RikkaTheme.spacing.lg), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { vm.nav.push(XRoute.DeviceWorkspace(person.id)) }, variant = ButtonVariant.Secondary, modifier = Modifier.fillMaxWidth()) { Text("اتصال یا مدیریت دستگاهها") }
                Button(onClick = { vm.nav.push(XRoute.OwnershipCorrection(personId = person.id)) }, variant = ButtonVariant.Ghost, modifier = Modifier.fillMaxWidth()) { Text("اصلاح بازهٔ مالکیت") }
                Button(onClick = { vm.nav.push(XRoute.PersonMerge(person.id)) }, variant = ButtonVariant.Ghost, modifier = Modifier.fillMaxWidth()) { Text("ادغام با شخص دیگر") }
            }
        }
        if (myDevices.isEmpty()) {
            item { Text("هیچ دستگاهی به این فرد متصل نیست.", variant = TextVariant.Muted, modifier = Modifier.padding(horizontal = RikkaTheme.spacing.lg)) }
        } else {
            items(myDevices, key = { it.mac }) { dev ->
                Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp)) {
                    Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) {
                            Text(dev.alias.ifBlank { dev.lastSeenName }, variant = TextVariant.P, style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold))
                            Text(dev.mac, variant = TextVariant.Muted)
                        }
                        IconButton(
                            icon = Icons.Filled.Delete,
                            contentDescription = "حذف از مالکیت",
                            onClick = { removingDevice = dev },
                        )
                    }
                }
            }
        }
        val former = ownership.filter { it.personId == personId && it.untilDay != null }
        if (former.isNotEmpty()) {
            item { SectionTitle("دستگاههای سابق") }
            items(former.sortedByDescending { it.untilDay }, key = { it.key }) { interval ->
                val device = devices.find { it.mac == interval.mac }
                Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp)) {
                    Text(device?.alias?.ifBlank { device.lastSeenName }?.ifBlank { interval.mac } ?: interval.mac, variant = TextVariant.P)
                    Text("مالکیت از ${Format.faNum(interval.sinceDay.toString())} تا ${Format.faNum(interval.untilDay.toString())}", variant = TextVariant.Muted)
                }
            }
        }
        item { SectionTitle("مصرف ماهانه") }
        item {
            val monthLabels = myEntries.map { jalaliMonthKeyLabel(it.monthKey).substringBefore(" ") }
            Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
                if (myEntries.isEmpty()) {
                    Text("هنوز ردیفی ثبت نشده.", variant = TextVariant.Muted)
                } else {
                    ColumnChart(
                        values = myEntries.map { it.usageGb },
                        labels = monthLabels.map { it.take(2) },
                        labelEvery = if (myEntries.size > 6) 2 else 1,
                        mini = true,
                        caption = "مصرف ماهانهٔ ${person.name} به گیگابایت",
                    )
                }
            }
        }
        item { SectionTitle("پرداخت‌ها") }
        items(myEntries, key = { it.key }) { e ->
            val amounts = history.first { it.key == e.key }.amounts
            Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp)) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.weight(1f)) {
                        Text(jalaliMonthKeyLabel(e.monthKey), style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold))
                        Text("${Format.gbValue(e.usageGb)} GB · نرخ ${Format.faNum(e.rateUsed.toString())} تومان", variant = TextVariant.Muted)
                    }
                    Column(horizontalAlignment = Alignment.End) {
                        Text(
                            if (amounts.status == LedgerPaymentStatus.PAID) "وصول: ${Format.faCompact(amounts.collection.toDouble())} ✓" else "باقیمانده: ${Format.faCompact(amounts.unpaid.toDouble())}",
                            color = if (amounts.status == LedgerPaymentStatus.PAID) StatusColors.up else StatusColors.down,
                            variant = TextVariant.Small,

                            style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold),
                        )
                    }
                    IconButton(icon = Icons.Filled.Tune, contentDescription = "ویرایش وصول", onClick = { paying = e })
                }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
    if (editing && person != null) PersonEditDialog(vm, person) { editing = false }
    paying?.let { entry -> PaymentEditDialog(vm, entry) { paying = null } }
    removingDevice?.let { device ->
        DestructiveActionDialog(
            title = "حذف مالکیت دستگاه؟",
            description = "«${device.alias.ifBlank { device.lastSeenName }.ifBlank { device.mac }}» بدون مالک میشود؛ سابقهٔ مالکیت حفظ خواهد شد.",
            configuredPin = vm.store.lockPin.takeIf { vm.store.appLockConfigured() }.orEmpty(),
            onDismiss = { removingDevice = null },
            onConfirm = { vm.setDeviceOwner(device.mac, null); removingDevice = null },
        )
    }
}

@Composable
private fun PersonEditDialog(vm: XirouterViewModel, person: PersonEntity, onClose: () -> Unit) {
    var name by remember { mutableStateOf(person.name) }
    var archiving by remember { mutableStateOf(false) }
    var group by remember { mutableStateOf(person.group) }
    var note by remember { mutableStateOf(person.note) }
    var rate by remember { mutableStateOf(person.rateOverride?.toString().orEmpty()) }
    var color by remember { mutableStateOf(person.colorIndex.toString()) }
    AlertDialog(
        open = true,
        onDismiss = onClose,
        onConfirm = {
            vm.updatePerson(
                person.copy(
                    name = name.trim(), group = group.trim(), note = note.trim(),
                    rateOverride = rate.takeIf(String::isNotBlank)?.let { (Format.parseAmount(it) ?: 0.0).toLong().takeIf { value -> value > 0 } },
                    colorIndex = color.toIntOrNull()?.coerceIn(0, 7) ?: person.colorIndex,
                ),
            )
            onClose()
        },
        content = {
            AlertDialogHeader("ویرایش فرد", description = "")
            Input(value = name, onValueChange = { name = it }, placeholder = "نام", modifier = Modifier.padding(top = 8.dp))
            Input(value = group, onValueChange = { group = it }, placeholder = "گروه", modifier = Modifier.padding(top = 8.dp))
            Input(value = note, onValueChange = { note = it }, placeholder = "یادداشت", label = "یادداشت", singleLine = false, modifier = Modifier.padding(top = 8.dp))
            Input(value = rate, onValueChange = { rate = it }, placeholder = "نرخ اختصاصی هر GB (اختیاری)", label = "نرخ اختصاصی", keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), visualTransformation = Format.GroupedNumber, clearable = true, modifier = Modifier.padding(top = 8.dp))
            Select(color, { color = it }, (0..7).map { SelectOption(it.toString(), "رنگ ${Format.faNum((it + 1).toString())}") }, Modifier.padding(top = 8.dp), label = "رنگ فرد")
            if (!person.archived) Button({ archiving = true }, variant = ButtonVariant.Destructive, modifier = Modifier.padding(top = 12.dp)) { Text("بایگانی فرد") }
        },
    )
    if (archiving) DestructiveActionDialog(
        title = "بایگانی «${person.name}»؟",
        description = "مالکیت فعلی دستگاهها پاک میشود؛ سوابق دفترحساب حفظ خواهد شد.",
        configuredPin = vm.store.lockPin.takeIf { vm.store.appLockConfigured() }.orEmpty(),
        onDismiss = { archiving = false },
        onConfirm = { vm.deletePerson(person.id); archiving = false; onClose() },
    )
}

/** Payment amount editor: partial payments allowed; the paid flag follows the amount. */
@Composable
private fun PaymentEditDialog(vm: XirouterViewModel, entry: LedgerEntryEntity, onClose: () -> Unit) {
    val persons by vm.persons.collectAsStateWithLifecycle()
    val person = persons.find { it.id == entry.personId }
    var amount by remember { mutableStateOf(entry.paidToman.toString()) }
    AlertDialog(
        open = true,
        onDismiss = onClose,
        onConfirm = {
            val paidToman = (Format.parseAmount(amount) ?: 0.0).toLong()
            vm.updateLedgerEntry(entry.key, entry.costOverride, paidToman, entry.note)
            onClose()
        },
        content = {
            AlertDialogHeader(
                "وصول «${person?.name ?: ""}»",
                description = "بدهی این ماه ${Format.faCompact(entry.owedToman.toDouble())} تومان است. مبلغ پرداختی را وارد کنید.",
            )
            Input(
                value = amount, onValueChange = { amount = it },
                placeholder = "مبلغ (تومان)",
                visualTransformation = Format.GroupedNumber,
                modifier = Modifier.padding(top = 8.dp),
            )
        },
    )
}

// ── Year report ──────────────────────────────────────────────────────────────

@Composable
fun YearReportScreen(vm: XirouterViewModel, initialYear: Int) {
    val months by vm.months.collectAsStateWithLifecycle()
    val entriesByMonth by vm.entriesByMonth.collectAsStateWithLifecycle()
    val personRows by vm.persons.collectAsStateWithLifecycle()
    val years = months.map { it.jYear }.distinct().sortedDescending()
    var year by remember { mutableStateOf(initialYear) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val toast = LocalToastHostState.current
    val csvLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri ->
        if (uri != null) scope.launch {
            val ok = Export.writeCsv(context, uri, vm.yearCsv(year))
            toast.show(if (ok) "خروجی سال ذخیره شد" else "خروجی نوشته نشد")
        }
    }

    val report = ledgerReadModel(personRows, months, entriesByMonth.values.flatten()).year(year)
    val owed = report.months.map { it.owed }
    val collected = report.months.map { it.collection }
    val totalOwed = report.summary.owed
    val totalCollected = report.summary.collected
    val personTotals = report.personTotals
    val groupTotals = report.groupTotals

    LazyColumn(Modifier.fillMaxWidth()) {
        item {
            Row(Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg), verticalAlignment = Alignment.CenterVertically) {
                Select(
                    selectedValue = "$year",
                    onValueChange = { year = it.toInt() },
                    options = years.map { SelectOption("$it", Format.faDigits("$it")) },
                    modifier = Modifier.weight(1f),
                )
                Spacer(Modifier.width(8.dp))
                Button(onClick = { scope.launch { csvLauncher.launch("xirouter-year-$year.csv") } }, variant = ButtonVariant.Secondary) { Text("خروجی CSV") }
            }
        }
        item {
            Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
                GroupedBars(
                    labels = (0 until 12).map { i -> JALALI_MONTH_NAMES_SHORT[i] },
                    first = owed.map { it.toDouble() },
                    second = collected.map { it.toDouble() },
                )
            }
        }
        item {
            Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = RikkaTheme.spacing.sm)) {
                DetailRow("بدهی کل", Format.faCompact(totalOwed.toDouble()), bold = true)
                DetailRow("وصول کل", Format.faCompact(totalCollected.toDouble()), bold = true)
                DetailRow("باقیمانده سال", Format.faCompact(report.summary.unpaid.toDouble()), bold = true)
            }
        }
        if (groupTotals.isNotEmpty()) item {
            SectionTitle("جمع گروهها")
            Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
                groupTotals.forEach { total ->
                    DetailRow(total.name, "${Format.faCompact(total.amounts.owed.toDouble())} / ${Format.faCompact(total.amounts.collection.toDouble())}")
                }
                Text("بدهی / وصول", variant = TextVariant.Small)
            }
        }
        if (personTotals.isNotEmpty()) item {
            SectionTitle("جمع افراد")
            Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
                personTotals.forEach { total ->
                    DetailRow(total.name, "${Format.faCompact(total.amounts.owed.toDouble())} / ${Format.faCompact(total.amounts.collection.toDouble())}")
                }
                Text("بدهی / وصول", variant = TextVariant.Small)
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
}

// ── Suggestions ──────────────────────────────────────────────────────────────

@Composable
fun SuggestionsScreen(vm: XirouterViewModel) {
    val devices by vm.devices.collectAsStateWithLifecycle()
    val personRows by vm.persons.collectAsStateWithLifecycle()
    val ownership by vm.ownership.collectAsStateWithLifecycle()
    val scope = rememberCoroutineScope()
    val toast = LocalToastHostState.current
    var sugg by remember { mutableStateOf<Map<String, List<ir.parsavisions.xirouter.OwnerSuggestion>>>(emptyMap()) }
    var selected by remember { mutableStateOf<Map<String, String>>(emptyMap()) }
    var lastDismissed by remember { mutableStateOf<Pair<String, ir.parsavisions.xirouter.OwnerSuggestion>?>(null) }
    var loaded by remember { mutableStateOf(false) }
    LaunchedEffect(devices, personRows, ownership) {
        val out = mutableMapOf<String, List<ir.parsavisions.xirouter.OwnerSuggestion>>()
        devices.filter { it.ownerPersonId == null }.forEach { d ->
            cancellationAwareResult { vm.suggestionsFor(d.mac) }.getOrNull()?.takeIf { it.isNotEmpty() }?.let { out[d.mac] = it }
        }
        sugg = out
        loaded = true
    }
    val persons = personRows.associateBy { it.id }

    LazyColumn(Modifier.fillMaxWidth()) {
        item {
            SectionTitle("دستگاههای بدون مالک")
            if (sugg.isNotEmpty()) Column(Modifier.padding(horizontal = RikkaTheme.spacing.lg), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { selected = sugg.mapNotNull { (mac, list) -> list.firstOrNull { it.confidence == SuggestionConfidence.HIGH }?.let { mac to it.personId } }.toMap() }, variant = ButtonVariant.Secondary, modifier = Modifier.fillMaxWidth()) { Text("انتخاب پیشنهادهای با اطمینان زیاد") }
                Button(onClick = { vm.applySuggestions(selected); scope.launch { toast.show("${Format.faNum(selected.size.toString())} پیشنهاد بهصورت امن اعمال شد") }; selected = emptyMap() }, enabled = selected.isNotEmpty(), modifier = Modifier.fillMaxWidth()) { Text("اعمال گروهی انتخابها (${Format.faNum(selected.size.toString())})") }
                lastDismissed?.let { (mac, suggestion) -> Button(onClick = { vm.undoDismissSuggestion(mac, suggestion.personId); lastDismissed = null }, variant = ButtonVariant.Ghost) { Text("واگردانی آخرین رد") } }
            }
        }
        if (!loaded) {

            items(3) { SkeletonBlock(56, Modifier.padding(horizontal = RikkaTheme.spacing.lg)) }
        } else if (sugg.isEmpty()) {
            item {
                EmptyState(
                    Icons.Filled.Lightbulb,
                    "پیشنهادی نیست",
                    "همهٔ دستگاه‌ها مالک دارند یا هنوز سیگنال کافی جمع نشده است.",
                    modifier = Modifier.padding(horizontal = RikkaTheme.spacing.lg),
                )
            }
        } else {
            sugg.forEach { (mac, list) ->
                val device = devices.find { it.mac == mac }
                item {
                    Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp)) {
                        Text(device?.alias?.ifBlank { device.lastSeenName } ?: mac, variant = TextVariant.P, style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold))
                        Text(mac, variant = TextVariant.Muted)
                        Spacer(Modifier.height(6.dp))
                        list.forEach { s ->
                            val person = persons[s.personId]
                            Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                                Column(Modifier.weight(1f)) {
                                    Text("«${person?.name ?: "؟"}» — ${confidenceText(s.confidence)} · ${reasonText(s.signals)}", variant = TextVariant.Small)
                                }
                                Checkbox(selected[mac] == s.personId, { checked -> selected = if (checked) selected + (mac to s.personId) else selected - mac }, label = "انتخاب")
                                Button(onClick = {
                                    vm.dismissSuggestion(mac, s.personId); lastDismissed = mac to s
                                    sugg = sugg + (mac to list.filterNot { it.personId == s.personId })
                                    scope.launch { toast.show("پیشنهاد رد شد؛ امکان واگردانی دارید") }
                                }, variant = ButtonVariant.Ghost, size = zed.rainxch.rikkaui.components.ui.button.ButtonSize.Sm) { Text("رد") }
                                Button(onClick = {
                                    vm.applySuggestion(mac, s.personId)
                                    scope.launch { toast.show("به «${person?.name}» متصل شد") }
                                }, size = zed.rainxch.rikkaui.components.ui.button.ButtonSize.Sm) { Text("اعمال") }
                            }
                        }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
}

private fun confidenceText(value: SuggestionConfidence) = when (value) {
    SuggestionConfidence.HIGH -> "اطمینان زیاد"
    SuggestionConfidence.MEDIUM -> "اطمینان متوسط"
    SuggestionConfidence.LOW -> "اطمینان کم"
}

private fun reasonText(signals: Set<SuggestionSignal>): String {
    val reasons = listOf(
        SuggestionSignal.HISTORY to "سابقهٔ مالکیت",
        SuggestionSignal.NAME to "نام مشابه",
        SuggestionSignal.OUI to "برند مشترک",
        SuggestionSignal.ACTIVITY to "استفادهٔ هم‌زمان",
    ).filter { it.first in signals }.map { it.second }
    return reasons.joinToString("، ").ifBlank { "سیگنال ضعیف" }
}

// ── People editor ────────────────────────────────────────────────────────────

@Composable
fun PeopleScreen(vm: XirouterViewModel) {
    val personRows by vm.persons.collectAsStateWithLifecycle()
    val devices by vm.devices.collectAsStateWithLifecycle()
    val people = personRows.filter { !it.implicit && !it.archived }
    val archived = personRows.filter { !it.implicit && it.archived }
    var showArchived by remember { mutableStateOf(false) }
    var showAdd by remember { mutableStateOf(false) }
    var editing by remember { mutableStateOf<PersonEntity?>(null) }
    var deleting by remember { mutableStateOf<PersonEntity?>(null) }

    LazyColumn(Modifier.fillMaxWidth()) {
        item {
            Column(Modifier.padding(horizontal = RikkaTheme.spacing.lg), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Button(onClick = { showAdd = true }, modifier = Modifier.fillMaxWidth()) { Text("افزودن فرد") }
                Button(onClick = { vm.nav.push(XRoute.PersonMerge()) }, enabled = people.size > 1, variant = ButtonVariant.Secondary, modifier = Modifier.fillMaxWidth()) { Text("پیشنمایش و ادغام اشخاص") }
                Button(onClick = { showArchived = !showArchived }, variant = ButtonVariant.Ghost, modifier = Modifier.fillMaxWidth()) { Text("بایگانی (${Format.faNum(archived.size.toString())})") }
            }
        }
        item { SectionTitle("افراد (${people.size})") }
        items(people, key = { it.id }) { person ->
            Card(
                onClick = { vm.nav.push(XRoute.Person(person.id)) },
                modifier = Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp),
            ) {
                Row(Modifier.padding(RikkaTheme.spacing.md), verticalAlignment = Alignment.CenterVertically) {
                    PersonAvatar(person.name, person.colorIndex, size = 40)
                    Spacer(Modifier.width(RikkaTheme.spacing.md))
                    Column(Modifier.weight(1f)) {
                        Text(person.name, variant = TextVariant.P, style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold))
                        Text(person.group, variant = TextVariant.Muted)
                    }
                    Text("${devices.count { it.ownerPersonId == person.id }} دستگاه", variant = TextVariant.Muted)
                }
            }
        }
        if (showArchived) {
            item { SectionTitle("افراد بایگانیشده") }
            if (archived.isEmpty()) item { Text("فرد بایگانیشدهای نیست.", variant = TextVariant.Muted, modifier = Modifier.padding(horizontal = RikkaTheme.spacing.lg)) }
            items(archived, key = { "archived-${it.id}" }) { person ->
                Card(modifier = Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp)) {
                    Row(Modifier.padding(RikkaTheme.spacing.md), verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) { Text(person.name, style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold)); Text("سوابق و اطلاعات مالی حفظ شده است", variant = TextVariant.Muted) }
                        Button(onClick = { vm.restorePerson(person.id) }, variant = ButtonVariant.Secondary) { Text("بازیابی") }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
    if (showAdd) {
        var name by remember { mutableStateOf("") }
        var group by remember { mutableStateOf("") }
        AlertDialog(
            open = showAdd,
            onDismiss = { showAdd = false },
            onConfirm = { vm.addPerson(name, group); showAdd = false },
            content = {
                AlertDialogHeader("فرد جدید", description = "نام و در صورت تمایل گروه (مثلاً خانواده، مهمان).")
                Input(value = name, onValueChange = { name = it }, placeholder = "نام", modifier = Modifier.padding(top = 8.dp))
                Input(value = group, onValueChange = { group = it }, placeholder = "گروه", modifier = Modifier.padding(top = 8.dp))
            },
        )
    }
    editing?.let { person ->
        var name by remember { mutableStateOf(person.name) }
        var group by remember { mutableStateOf(person.group) }
        var note by remember { mutableStateOf(person.note) }
        AlertDialog(
            open = true,
            onDismiss = { editing = null },
            onConfirm = {
                vm.updatePerson(person.copy(name = name.trim(), group = group.trim(), note = note))
                editing = null
            },
            content = {
                AlertDialogHeader("ویرایش فرد", description = "")
                Input(value = name, onValueChange = { name = it }, placeholder = "نام", modifier = Modifier.padding(top = 8.dp))
                Input(value = group, onValueChange = { group = it }, placeholder = "گروه", modifier = Modifier.padding(top = 8.dp))
                Input(value = note, onValueChange = { note = it }, placeholder = "یادداشت", modifier = Modifier.padding(top = 8.dp))
                Button(
                    onClick = { deleting = person; editing = null },
                    variant = ButtonVariant.Destructive,
                    modifier = Modifier.padding(top = 12.dp),
                ) { Text("حذف فرد") }
            },
        )
    }
    deleting?.let { person ->
        DestructiveActionDialog(
            title = "حذف «${person.name}»؟",
            description = "مالکیت فعلی دستگاهها پاک میشود؛ نام فرد برای سوابق و گزارشها نگه داشته خواهد شد.",
            configuredPin = vm.store.lockPin.takeIf { vm.store.appLockConfigured() }.orEmpty(),
            onDismiss = { deleting = null },
            onConfirm = { vm.deletePerson(person.id); deleting = null },
        )
    }
}

@Composable
fun OwnershipCorrectionScreen(vm: XirouterViewModel, initialMac: String?, initialPersonId: String?) {
    val devices by vm.devices.collectAsStateWithLifecycle()
    val people by vm.persons.collectAsStateWithLifecycle()
    val editable = people.filter { !it.archived && !it.implicit }
    val today = jalaliOf(tehranDay(System.currentTimeMillis()))
    var mac by remember { mutableStateOf(initialMac ?: devices.firstOrNull()?.mac.orEmpty()) }
    var personId by remember { mutableStateOf(initialPersonId ?: editable.firstOrNull()?.id.orEmpty()) }
    var startYear by remember { mutableStateOf(today.year.toString()) }; var startMonth by remember { mutableStateOf(today.month.toString()) }; var startDay by remember { mutableStateOf("1") }
    var openEnded by remember { mutableStateOf(true) }; var endYear by remember { mutableStateOf(today.year.toString()) }; var endMonth by remember { mutableStateOf(today.month.toString()) }; var endDay by remember { mutableStateOf(today.day.toString()) }
    var plan by remember { mutableStateOf<OwnershipCorrectionPlan?>(null) }; var busy by remember { mutableStateOf(false) }; var confirming by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope(); val toast = LocalToastHostState.current
    fun request(): OwnershipCorrectionRequest? = runCatching {
        OwnershipCorrectionRequest(mac, personId, jalaliDay(startYear.toInt(), startMonth.toInt(), startDay.toInt()),
            if (openEnded) null else jalaliDay(endYear.toInt(), endMonth.toInt(), endDay.toInt()))
    }.getOrNull()
    LazyColumn(Modifier.fillMaxWidth()) {
        item { Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
            Text("بازهٔ درست مالکیت را انتخاب کنید", variant = TextVariant.H4)
            Text("این عملیات فقط تخصیص مصرف را بازسازی میکند؛ مبلغ پرداختی، هزینهٔ دستی و یادداشتهای مالی حفظ میشوند.", variant = TextVariant.Muted, modifier = Modifier.padding(bottom = 12.dp))
            Select(mac, { mac = it; plan = null }, devices.map { SelectOption(it.mac, it.alias.ifBlank { it.lastSeenName }.ifBlank { Format.bidi(it.mac) }) }, label = "Device", modifier = Modifier.fillMaxWidth())
            Select(personId, { personId = it; plan = null }, editable.map { SelectOption(it.id, it.name) }, label = "Person", modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
            Text("شروع (هجری شمسی)", variant = TextVariant.Small, modifier = Modifier.padding(top = 12.dp))
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { Input(startYear, { startYear = it.filter(Char::isDigit); plan = null }, Modifier.weight(1f), label = "سال"); Input(startMonth, { startMonth = it.filter(Char::isDigit); plan = null }, Modifier.weight(1f), label = "ماه"); Input(startDay, { startDay = it.filter(Char::isDigit); plan = null }, Modifier.weight(1f), label = "روز") }
            Checkbox(openEnded, { openEnded = it; plan = null }, label = "تا امروز و آینده")
            if (!openEnded) { Text("پایان (انحصاری)", variant = TextVariant.Small); Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) { Input(endYear, { endYear = it.filter(Char::isDigit); plan = null }, Modifier.weight(1f), label = "سال"); Input(endMonth, { endMonth = it.filter(Char::isDigit); plan = null }, Modifier.weight(1f), label = "ماه"); Input(endDay, { endDay = it.filter(Char::isDigit); plan = null }, Modifier.weight(1f), label = "روز") } }
            Button(onClick = { request()?.let { value -> busy = true; scope.launch { plan = cancellationAwareResult { vm.previewCorrection(value) }.getOrNull(); busy = false } } }, enabled = !busy && mac.isNotBlank() && personId.isNotBlank(), modifier = Modifier.fillMaxWidth().padding(top = 12.dp)) { Text(if (busy) "در حال محاسبه…" else "پیشنمایش") }
        } }
        plan?.let { value -> item { Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 12.dp)) {
            Text("نتیجهٔ پیشنمایش", variant = TextVariant.H4)
            Text("ماههای متاثر: ${value.affectedMonthKeys.sorted().joinToString("، ").ifBlank { "هیچ" }}", variant = TextVariant.P)
            Text(if (value.conflicts.isEmpty()) "تعارضی نیست" else "${Format.faNum(value.conflicts.size.toString())} بازهٔ قبلی جایگزین/کوتاه میشود", variant = TextVariant.Muted)
            value.conflicts.forEach { Text("${people.find { p -> p.id == it.range.personId }?.name ?: it.range.personId}: ${it.range.startDay} تا ${it.range.endDay ?: "ادامه"}", variant = TextVariant.Small) }
            Text("ماه بسته دوباره باز میشود، اما وصول، مبلغ دستی و یادداشت حفظ میشود.", variant = TextVariant.Small, modifier = Modifier.padding(top = 8.dp))
            Button(onClick = { confirming = true }, enabled = value.valid, variant = ButtonVariant.Destructive, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) { Text("تأیید با پین و اعمال") }
        } } }
    }
    if (confirming) DestructiveActionDialog("اعمال اصلاح مالکیت؟", "تعارضهای نشان دادهشده جایگزین و ماههای متاثر بازسازی میشوند. دادهٔ مالی دستی حفظ میشود.", vm.store.lockPin.takeIf { vm.store.appLockConfigured() }.orEmpty(), { confirming = false }) {
        val value = plan ?: return@DestructiveActionDialog
        confirming = false; busy = true; vm.applyCorrection(value.request) { result -> busy = false; scope.launch { toast.show(if (result.isSuccess) "اصلاح مالکیت اعمال شد" else "اعمال اصلاح ناموفق بود") }; if (result.isSuccess) vm.nav.pop() }
    }
}

@Composable
fun PersonMergeScreen(vm: XirouterViewModel, initialPersonId: String?) {
    val people by vm.persons.collectAsStateWithLifecycle(); val editable = people.filter { !it.archived && !it.implicit }
    var survivor by remember { mutableStateOf(initialPersonId ?: editable.firstOrNull()?.id.orEmpty()) }
    var source by remember { mutableStateOf(editable.firstOrNull { it.id != survivor }?.id.orEmpty()) }
    var choice by remember { mutableStateOf(MergeManualChoice.REQUIRE_EXPLICIT.name) }; var plan by remember { mutableStateOf<PersonMergePlan?>(null) }; var busy by remember { mutableStateOf(false) }; var confirming by remember { mutableStateOf(false) }
    val scope = rememberCoroutineScope(); val toast = LocalToastHostState.current
    fun request() = PersonMergeRequest(survivor, source, MergeManualChoice.valueOf(choice))
    LazyColumn(Modifier.fillMaxWidth()) {
        item { Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
            Text("انتخاب بازمانده و منبع", variant = TextVariant.H4)
            Text("شخص منبع حذف میشود؛ Deviceها، سابقهٔ مالکیت و ردیفهای Ledger به شخص بازمانده منتقل میشوند.", variant = TextVariant.Muted)
            Select(survivor, { survivor = it; if (source == it) source = editable.firstOrNull { p -> p.id != it }?.id.orEmpty(); plan = null }, editable.map { SelectOption(it.id, it.name) }, label = "شخص بازمانده", modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
            Select(source, { source = it; plan = null }, editable.filter { it.id != survivor }.map { SelectOption(it.id, it.name) }, label = "شخص منبع", modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
            Button({ busy = true; scope.launch { plan = cancellationAwareResult { vm.previewMerge(request()) }.getOrNull(); busy = false } }, enabled = !busy && survivor.isNotBlank() && source.isNotBlank() && survivor != source, modifier = Modifier.fillMaxWidth().padding(top = 12.dp)) { Text(if (busy) "در حال محاسبه…" else "پیشنمایش ادغام") }
        } }
        plan?.let { value -> item { Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 12.dp)) {
            Text("${Format.faNum(value.currentDeviceCount.toString())} Device · ${Format.faNum(value.historyCount.toString())} بازهٔ تاریخی · ${Format.faNum(value.affectedMonthKeys.size.toString())} ماه", variant = TextVariant.H4)
            Text("پرداختها با هم جمع میشوند و یادداشت منبع با برچسب ادغام حفظ میشود.", variant = TextVariant.Muted)
            if (value.conflicts.isNotEmpty()) {
                Text("تعارض پول دستی در: ${value.conflicts.joinToString("، ") { it.monthKey }}", color = StatusColors.warning, modifier = Modifier.padding(top = 8.dp))
                Select(choice, { choice = it; plan = value.copy(request = request()) }, listOf(SelectOption(MergeManualChoice.REQUIRE_EXPLICIT.name, "انتخاب لازم است"), SelectOption(MergeManualChoice.SURVIVOR.name, "مبلغ دستی بازمانده"), SelectOption(MergeManualChoice.SOURCE.name, "مبلغ دستی منبع"), SelectOption(MergeManualChoice.SUM_PAYMENTS.name, "محاسبهٔ دوباره؛ جمع وصول")), label = "حل تعارض دستی", modifier = Modifier.fillMaxWidth().padding(top = 8.dp))
            }
            Button({ confirming = true }, enabled = value.conflicts.isEmpty() || choice != MergeManualChoice.REQUIRE_EXPLICIT.name, variant = ButtonVariant.Destructive, modifier = Modifier.fillMaxWidth().padding(top = 12.dp)) { Text("تأیید با پین و ادغام") }
        } } }
    }
    if (confirming) DestructiveActionDialog("ادغام اشخاص؟", "شخص منبع حذف میشود و بازگردانی خودکار ندارد. پول دستی طبق انتخاب پیشنمایش حفظ میشود.", vm.store.lockPin.takeIf { vm.store.appLockConfigured() }.orEmpty(), { confirming = false }) {
        confirming = false; busy = true; vm.applyMerge(request()) { result -> busy = false; scope.launch { toast.show(if (result.isSuccess) "ادغام با موفقیت انجام شد" else "ادغام ناموفق بود") }; if (result.isSuccess) vm.nav.pop() }
    }
}

private val JALALI_MONTH_NAMES_SHORT = listOf("فروردین", "اردیبهشت", "خرداد", "تیر", "مرداد", "شهریور", "مهر", "آبان", "آذر", "دی", "بهمن", "اسفند")
