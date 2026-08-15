package ir.parsavisions.xirouter.ui

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.imePadding
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.material.icons.filled.CloudOff
import androidx.compose.material.icons.filled.Devices
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material.icons.filled.WifiOff
import androidx.compose.runtime.Composable
import androidx.compose.runtime.DisposableEffect
import androidx.compose.runtime.LaunchedEffect
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import ir.parsavisions.xirouter.BulkDeviceChange
import ir.parsavisions.xirouter.BulkValue
import ir.parsavisions.xirouter.ChartMath
import ir.parsavisions.xirouter.cancellationAwareResult
import ir.parsavisions.xirouter.CostRow
import ir.parsavisions.xirouter.DeviceSettingsEntity
import ir.parsavisions.xirouter.Format
import ir.parsavisions.xirouter.OwnerSuggestion
import ir.parsavisions.xirouter.PackageDisplayMode
import ir.parsavisions.xirouter.PackageEntity
import ir.parsavisions.xirouter.PackageInsights
import ir.parsavisions.xirouter.PackageSnapshotEntity
import ir.parsavisions.xirouter.SampleEntity
import ir.parsavisions.xirouter.UsageRow
import ir.parsavisions.xirouter.XirouterViewModel
import java.time.LocalDate
import java.time.LocalDateTime
import java.time.ZoneId
import java.time.format.DateTimeFormatter
import zed.rainxch.rikkaui.components.ui.badge.Badge
import zed.rainxch.rikkaui.components.ui.badge.BadgeSize
import zed.rainxch.rikkaui.components.ui.badge.BadgeVariant
import zed.rainxch.rikkaui.components.ui.button.Button
import zed.rainxch.rikkaui.components.ui.button.ButtonVariant
import zed.rainxch.rikkaui.components.ui.button.IconButton
import zed.rainxch.rikkaui.components.ui.card.Card
import zed.rainxch.rikkaui.components.ui.icon.Icon
import zed.rainxch.rikkaui.components.ui.input.Input
import zed.rainxch.rikkaui.components.ui.select.Select
import zed.rainxch.rikkaui.components.ui.select.SelectOption
import zed.rainxch.rikkaui.components.ui.sheet.Sheet
import zed.rainxch.rikkaui.components.ui.sheet.SheetHeader
import zed.rainxch.rikkaui.components.ui.sheet.SheetSide
import zed.rainxch.rikkaui.components.ui.text.Text
import zed.rainxch.rikkaui.components.ui.text.TextVariant
import zed.rainxch.rikkaui.components.ui.toggle.Toggle
import zed.rainxch.rikkaui.components.ui.toast.LocalToastHostState
import zed.rainxch.rikkaui.foundation.RikkaTheme

/** Data plan: balance, pacing, per-device ranking (GB/Toman), device management. */
@Composable
fun DataScreen(vm: XirouterViewModel) {
    LaunchedEffect(Unit) { vm.refreshBalance(); vm.refreshHistory(); vm.refreshUsageMonth(); vm.refreshBill() }
    val balance = vm.balance.value
    val main = balance?.main
    val localBalance by vm.localBalanceSamples.collectAsStateWithLifecycle()
    val localUsage by vm.localUsageSamples.collectAsStateWithLifecycle()
    var mode by remember { mutableStateOf("gb") }
    var packageMode by remember { mutableStateOf(PackageDisplayMode.parse(vm.store.packageDisplayMode)) }
    var editing by remember { mutableStateOf<DeviceSettingsEntity?>(null) }
    var editingPackage by remember { mutableStateOf<PackageEntity?>(null) }
    val packages by vm.packages.collectAsStateWithLifecycle()
    val devices by vm.devices.collectAsStateWithLifecycle()
    val personRows by vm.persons.collectAsStateWithLifecycle()
    val persons = personRows.associateBy { it.id }
    var suggestions by remember { mutableStateOf<Map<String, OwnerSuggestion>>(emptyMap()) }
    LaunchedEffect(devices, personRows) {
        suggestions = devices.filter { it.ownerPersonId == null }.mapNotNull { dev ->
            cancellationAwareResult { vm.suggestionsFor(dev.mac).firstOrNull()?.let { dev.mac to it } }.getOrNull()
        }.toMap()
    }

    val rankings = deviceRankings(vm.usageMonth.value?.rows.orEmpty(), vm.bill.value?.rows.orEmpty(), devices)
    val maxRank = when (mode) {
        "toman" -> rankings.maxOfOrNull { it.toman.toDouble() }
        else -> rankings.maxOfOrNull { it.gb }
    }?.coerceAtLeast(1.0) ?: 1.0

    LazyColumn(Modifier.fillMaxWidth()) {
        item { DataPlanHero(vm) }
        item { PackageDisplayChoice(packageMode) { packageMode = it; vm.store.packageDisplayMode = it.value } }
        val shownPackages = packages.filter { !it.archived && (it.visible || it.unconfirmed) }
            .sortedWith(compareBy<PackageEntity> { it.displayOrder }.thenBy { it.priority }.thenBy { it.id })
        when (packageMode) {
            PackageDisplayMode.AGGREGATE -> if (shownPackages.isNotEmpty()) item { AggregatePackageCard(shownPackages) }
            PackageDisplayMode.SEGMENTED -> if (shownPackages.isNotEmpty()) item { SegmentedPackageCard(shownPackages) }
            PackageDisplayMode.PACKAGE -> items(shownPackages, key = { "package-${it.id}" }) { pkg ->
                PackageCard(vm, pkg, onClick = { editingPackage = pkg }, onUp = { vm.movePackage(pkg.id, -1) }, onDown = { vm.movePackage(pkg.id, 1) })
            }
        }
        if (packages.any { it.archived }) item { ArchivedPackages(packages.filter { it.archived }, onEdit = { editingPackage = it }) }
        item { SectionTitle("روند موجودی") }
        item {
            Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
                val series = ChartMath.mergeSamples(
                    balance?.series.orEmpty().mapNotNull { point ->
                        parseRouterTs(point.date)?.let { ChartMath.TimedValue(it, point.gb) }
                    },
                    localBalance.toTimedValues(),
                    86_400_000L,
                )
                if (series.size >= 2) {
                    BalanceTrend(
                        samples = series,
                        quota = main?.quota?.toDouble(),
                        caption = "آخرین مقدار: ${Format.gbValue(series.last().value)} گیگابایت",
                    )
                } else {
                    Text("هنوز دادهٔ کافی برای نمودار نیست.", variant = TextVariant.Muted)
                }
            }
        }
        item { SectionTitle("مصرف روزانهٔ این ماه") }
        item {
            Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
                val cumulative = ChartMath.mergeSamples(
                    vm.historyUsage.value?.points.orEmpty().mapNotNull { point ->
                        parseRouterTs(point.ts)?.let { ChartMath.TimedValue(it, point.value) }
                    },
                    localUsage.toTimedValues(),
                    3_600_000L,
                )
                val daily = ChartMath.jalaliMonthDailyUsage(cumulative, System.currentTimeMillis())
                if (daily.isNotEmpty()) {
                    val pace = daily.map { it.value }.average()
                    ColumnChart(
                        values = daily.map { it.value },
                        labels = daily.mapIndexed { i, _ -> Format.faDigits("${i + 1}") },
                        labelEvery = if (daily.size > 16) 5 else 3,
                        color = StatusColors.info,
                        caption = "میانگین روزهای سپریشده: ${Format.gbValue(pace)} گیگابایت",
                    )
                } else {
                    Text("هنوز مصرفی ثبت نشده است.", variant = TextVariant.Muted)
                }
            }
        }
        item { SectionTitle("مصرف این ماه به تفکیک دستگاه") }
        item {
            BoxWithConstraints(Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg)) {
                val compact = maxWidth < 360.dp || LocalDensity.current.fontScale > 1.2f
                if (compact) {
                    Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                        Text("مقدار نمایش", variant = TextVariant.Muted)
                        RankingSelect(mode, onChange = { mode = it })
                    }
                } else {
                    Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                        Text("مقدار نمایش:", variant = TextVariant.Muted, modifier = Modifier.padding(end = 8.dp))
                        RankingSelect(mode, Modifier.weight(1f), onChange = { mode = it })
                    }
                }
            }
        }
        val rows = rankings.sortedByDescending { if (mode == "gb") it.gb else it.toman.toDouble() }
        if (rows.isEmpty()) {
            item {
                EmptyState(
                    Icons.Filled.WifiOff,
                    "داده‌ای نیست",
                    "مصرف این ماه هنوز اندازه‌گیری نشده.",
                    modifier = Modifier.padding(horizontal = RikkaTheme.spacing.lg),
                )
            }
        } else {
            items(rows, key = { it.mac }) { row ->
                val primary = if (mode == "gb") "${Format.gbValue(row.gb)} ${Format.bidi("GB")}" else "${Format.toman(row.toman)} تومان"
                val secondary = if (mode == "gb") "${Format.toman(row.toman)} تومان" else "${Format.gbValue(row.gb)} ${Format.bidi("GB")}"
                val share = Format.pct(row.share)
                Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp)) {
                    RankRow(row.label, "$primary · $secondary · $share", ((if (mode == "gb") row.gb else row.toman.toDouble()) / maxRank).toFloat())
                }
            }
        }
        item {
            SectionTitle("دستگاهها (${devices.size})")
            Button(onClick = { vm.nav.push(XRoute.DeviceWorkspace()) }, variant = ButtonVariant.Secondary, modifier = Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg)) { Text("مدیریت گروهی دستگاهها") }
        }
        items(devices.sortedBy { it.alias.lowercase() }, key = { it.mac }) { dev ->
            val owner = dev.ownerPersonId?.let { persons[it]?.name }
            Card(
                onClick = { editing = dev },
                modifier = Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp),
            ) {
                Row(Modifier.padding(RikkaTheme.spacing.md), verticalAlignment = Alignment.CenterVertically) {
                    Icon(Icons.Filled.Devices, contentDescription = null, tint = RikkaTheme.colors.onMuted)
                    Spacer(Modifier.width(RikkaTheme.spacing.md))
                    Column(Modifier.weight(1f)) {
                        Text(dev.alias.ifBlank { dev.lastSeenName }, variant = TextVariant.P, style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold))
                        Text(
                            listOfNotNull(Format.bidi(dev.mac), owner?.let { "مالک: $it" }, if (dev.hideFromLedger) "مخفی" else null, if (dev.watched) "تحت نظر" else null).joinToString(" · "),
                            variant = TextVariant.Muted,
                        )
                        suggestions[dev.mac]?.let { suggestion ->
                            persons[suggestion.personId]?.name?.let { name ->
                                Badge("مالک پیشنهادی: $name", variant = BadgeVariant.Outline, size = BadgeSize.Sm, modifier = Modifier.padding(top = 6.dp))
                            }
                        }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
    editing?.let { dev -> DeviceEditorSheet(vm, dev) { editing = null } }
    editingPackage?.let { pkg -> PackageEditorSheet(vm, pkg) { editingPackage = null } }
}

@Composable
private fun DataPlanHero(vm: XirouterViewModel) {
    val balance = vm.balance.value
    val aggregate = balance?.aggregate()
    val main = balance?.main
    val initialLoading = vm.balanceLoading.value && balance == null
    val unavailable = aggregate == null || (!balance.cached && balance.as_of_unix == 0L)
    Card(Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg)) {
        when {
            initialLoading -> SkeletonBlock(112, Modifier.padding(RikkaTheme.spacing.lg))
            unavailable -> Column(Modifier.padding(RikkaTheme.spacing.lg), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Icon(Icons.Filled.CloudOff, contentDescription = null, tint = RikkaTheme.colors.onMuted)
                Text(if (vm.balanceError.value != null) "بستهٔ اینترنت در دسترس نیست" else "اطلاعات بسته هنوز آماده نیست", variant = TextVariant.H4)
                Text(vm.balanceError.value ?: "روتر هنوز موجودی معتبری برنگردانده است.", variant = TextVariant.Muted)
                Button(onClick = vm::refreshBalance, enabled = !vm.balanceLoading.value, variant = ButtonVariant.Secondary) {
                    Icon(Icons.Filled.Refresh, contentDescription = null)
                    Text(if (vm.balanceLoading.value) "در حال دریافت…" else "تلاش دوباره")
                }
            }
            else -> {
                BoxWithConstraints(Modifier.fillMaxWidth().padding(RikkaTheme.spacing.lg)) {
                    val compact = maxWidth < 360.dp || LocalDensity.current.fontScale > 1.2f
                    if (compact) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.fillMaxWidth()) {
                            val pct = aggregate.remain_gb?.let { r -> aggregate.quota_gb?.takeIf { it > 0 }?.let { (r / it * 100).toInt() } } ?: main?.pct ?: 0
                            GaugeRing(pct, label = "${Format.faDigits("$pct")}٪", size = 72)
                            Spacer(Modifier.height(8.dp))
                            PlanText(aggregate.remain_gb, aggregate.quota_gb?.toInt(), main?.days, aggregate.expiry, Modifier.fillMaxWidth())
                        }
                    } else {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            val pct = aggregate.remain_gb?.let { r -> aggregate.quota_gb?.takeIf { it > 0 }?.let { (r / it * 100).toInt() } } ?: main?.pct ?: 0
                            GaugeRing(pct, label = "${Format.faDigits("$pct")}٪", size = 80)
                            Spacer(Modifier.width(RikkaTheme.spacing.lg))
                            PlanText(aggregate.remain_gb, aggregate.quota_gb?.toInt(), main?.days, aggregate.expiry, Modifier.weight(1f))
                        }
                    }
                }
                if (balance.cached || vm.balanceError.value != null) {
                    Text(
                        if (vm.balanceError.value != null) "آفلاین؛ نمایش آخرین موجودی دریافتشده" else "دادهٔ ذخیرهشده؛ ممکن است بهروز نباشد",
                        variant = TextVariant.Small,
                        modifier = Modifier.padding(horizontal = RikkaTheme.spacing.lg),
                    )
                    Button(onClick = vm::refreshBalance, enabled = !vm.balanceLoading.value, variant = ButtonVariant.Ghost, modifier = Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
                        Text(if (vm.balanceLoading.value) "در حال دریافت…" else "بهروزرسانی")
                    }
                }
                balance.drain?.takeIf { it.isNotBlank() }?.let {
                    Text("روند: ${Format.bidi(it)}", variant = TextVariant.Small, modifier = Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 6.dp))
                }
            }
        }
    }
}

@Composable
private fun PlanText(remain: Double?, quota: Int?, days: Int?, expires: String?, modifier: Modifier) = Column(modifier) {
    Text("بستهٔ اینترنت", variant = TextVariant.Muted)
    FigureText("${Format.gbValue(remain ?: 0.0)} ${Format.bidi("GB")}", variant = TextVariant.H3, fontWeight = FontWeight.Bold)
    Text(
        "از ${Format.gbValue(quota?.toDouble() ?: 0.0)} گیگابایت · ${days?.let { "انقضا ${Format.faDigits("$it")} روز دیگر" } ?: "انقضا: ${expires?.let(Format::bidi) ?: "—"}"}",
        variant = TextVariant.Muted,
    )
}

@Composable
private fun PackageDisplayChoice(mode: PackageDisplayMode, onChange: (PackageDisplayMode) -> Unit) {
    Column(Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = 8.dp)) {
        Select(selectedValue = mode.value, onValueChange = { onChange(PackageDisplayMode.parse(it)) },
            options = listOf(SelectOption("aggregate", "مجموع"), SelectOption("segmented", "تفکیکی"), SelectOption("package", "هر بسته")),
            label = "نمایش طرح اینترنت", modifier = Modifier.fillMaxWidth())
    }
}

@Composable
private fun AggregatePackageCard(packages: List<PackageEntity>) {
    val remain = packages.sumOf { it.remainGb ?: 0.0 }; val quota = packages.sumOf { it.quotaGb ?: 0.0 }
    Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp)) {
        Text("مجموع ${Format.faNum(packages.size.toString())} بسته", variant = TextVariant.H4)
        Text("مانده ${Format.gbValue(remain)} از ${Format.gbValue(quota)} گیگابایت", variant = TextVariant.P)
        GaugeRing(if (quota > 0) (remain / quota * 100).toInt() else 0, size = 56)
    }
}

@Composable
private fun SegmentedPackageCard(packages: List<PackageEntity>) {
    Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp)) {
        Text("سهم بستهها از موجودی", variant = TextVariant.H4)
        packages.forEach { pkg ->
            val quota = pkg.quotaGb ?: 0.0
            RankRow(pkg.alias.ifBlank { pkg.routerName.ifBlank { pkg.id } }, "${Format.gbValue(pkg.remainGb ?: 0.0)} GB", if (quota > 0) ((pkg.remainGb ?: 0.0) / quota).toFloat() else 0f)
        }
    }
}

@Composable
private fun PackageCard(vm: XirouterViewModel, pkg: PackageEntity, onClick: () -> Unit, onUp: () -> Unit, onDown: () -> Unit) {
    var snapshots by remember(pkg.id, pkg.lastSeenUnix) { mutableStateOf<List<PackageSnapshotEntity>>(emptyList()) }
    LaunchedEffect(pkg.id, pkg.lastSeenUnix) { snapshots = vm.packageSnapshots(pkg.id) }
    val rate = PackageInsights.dailyConsumption(snapshots)
    val info = PackageInsights.calculate(pkg, rate)
    Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp), onClick = onClick) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            if (pkg.color.isNotBlank()) Text("●", color = runCatching { androidx.compose.ui.graphics.Color(android.graphics.Color.parseColor(pkg.color)) }.getOrDefault(StatusColors.info), modifier = Modifier.padding(end = 8.dp))
            Column(Modifier.weight(1f)) {
                Text(pkg.alias.ifBlank { pkg.routerName.ifBlank { pkg.type.ifBlank { pkg.provider } } }, variant = TextVariant.H4)
                Text(listOfNotNull(pkg.provider.takeIf { it.isNotBlank() }, pkg.localCategory.takeIf { it.isNotBlank() },
                    if (pkg.unconfirmed) "تأییدنشده" else null).joinToString(" · "), variant = TextVariant.Muted)
            }
            IconButton(Icons.Filled.ArrowUpward, "انتقال بسته به بالا", onClick = onUp)
            IconButton(Icons.Filled.ArrowDownward, "انتقال بسته به پایین", onClick = onDown)
            GaugeRing(info.remainingPct ?: 0, label = "${Format.faDigits("${info.remainingPct ?: 0}")}٪", size = 56)
        }
        Text("مانده ${Format.gbValue(pkg.remainGb ?: 0.0)} از ${Format.gbValue(pkg.quotaGb ?: 0.0)} گیگابایت · مصرف ${Format.gbValue(pkg.consumedGb ?: 0.0)}", variant = TextVariant.P)
        Text(listOfNotNull(info.daysToExpiry?.let { "انقضا تا ${Format.faDigits("$it")} روز" }, info.depletionDays?.let { "اتمام بر پایهٔ تاریخچه: ${Format.faDigits("${it.toInt()}")} روز" },
            snapshots.takeIf { it.size > 1 }?.let { "${Format.faNum(it.size.toString())} نقطهٔ تاریخچه" }).joinToString(" · ").ifBlank { "تاریخچه برای برآورد کافی نیست" }, variant = TextVariant.Muted)
    }
}

@Composable
private fun ArchivedPackages(packages: List<PackageEntity>, onEdit: (PackageEntity) -> Unit) {
    var query by remember { mutableStateOf("") }
    Column(Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg)) {
        SectionTitle("بستههای بایگانیشده")
        Input(query, { query = it }, placeholder = "جستجو", label = "جستجوی بستههای بایگانیشده")
        packages.filter { query.isBlank() || listOf(it.alias, it.routerName, it.provider, it.id).any { value -> value.contains(query, true) } }
            .forEach { pkg ->
                Card(onClick = { onEdit(pkg) }, modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp)) {
                    Column(Modifier.padding(RikkaTheme.spacing.md)) {
                        Text(pkg.alias.ifBlank { pkg.routerName.ifBlank { pkg.id } }, variant = TextVariant.P)
                        Text("آخرین مانده ${Format.gbValue(pkg.remainGb ?: 0.0)} گیگابایت", variant = TextVariant.Muted)
                    }
                }
            }
    }
}

@Composable
private fun PackageEditorSheet(vm: XirouterViewModel, pkg: PackageEntity, onClose: () -> Unit) {
    var alias by remember { mutableStateOf(pkg.alias) }; var color by remember { mutableStateOf(pkg.color) }
    var category by remember { mutableStateOf(pkg.localCategory) }; var note by remember { mutableStateOf(pkg.note) }
    var visible by remember { mutableStateOf(pkg.visible) }; var muted by remember { mutableStateOf(pkg.alertsMuted) }
    var threshold by remember { mutableStateOf(pkg.alertThresholdPct?.toString().orEmpty()) }
    Sheet(open = true, onDismiss = onClose, side = SheetSide.Left, modifier = Modifier.imePadding(), label = "ویرایش بسته") {
        Column(Modifier.fillMaxWidth().fillMaxHeight().verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            SheetHeader("بسته", description = Format.bidi(pkg.id))
            Text("اطلاعات ارائهدهنده و مقدارها فقط خواندنیاند.", variant = TextVariant.Muted)
            Text("${pkg.provider} · ${Format.gbValue(pkg.remainGb ?: 0.0)} / ${Format.gbValue(pkg.quotaGb ?: 0.0)} GB", variant = TextVariant.P)
            Input(alias, { alias = it }, placeholder = "نام محلی", label = "نام محلی")
            Input(color, { color = it }, placeholder = "رنگ", label = "رنگ")
            Input(category, { category = it }, placeholder = "دسته", label = "دسته محلی")
            Input(note, { note = it }, placeholder = "یادداشت", label = "یادداشت")
            Input(threshold, { threshold = it.filter(Char::isDigit).take(3) }, placeholder = "مثلاً ۲۰", label = "آستانه هشدار درصد")
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { Text("نمایش بسته", Modifier.weight(1f)); Toggle(visible, { visible = it }) }
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { Text("بیصدا کردن هشدار", Modifier.weight(1f)); Toggle(muted, { muted = it }) }
            Button(onClick = { vm.updatePackageMetadata(pkg.copy(alias = alias, color = color, localCategory = category, note = note,
                visible = visible, alertsMuted = muted, alertThresholdPct = threshold.toIntOrNull())); onClose() }, modifier = Modifier.fillMaxWidth()) { Text("ذخیره") }
        }
    }
}

@Composable
private fun RankingSelect(mode: String, modifier: Modifier = Modifier, onChange: (String) -> Unit) = Select(
    selectedValue = mode,
    onValueChange = onChange,
    options = listOf(SelectOption("gb", "گیگابایت"), SelectOption("toman", "تومان")),
    label = "مقدار نمایش رتبهبندی",
    modifier = modifier.fillMaxWidth(),
)

internal data class DeviceRanking(val mac: String, val label: String, val gb: Double, val toman: Long, val share: Double)

internal fun deviceRankings(usage: List<UsageRow>, costs: List<CostRow>, devices: List<DeviceSettingsEntity>): List<DeviceRanking> {
    val devicesByMac = devices.associateBy { it.mac.lowercase() }
    val usageByMac = usage.filter { it.mac.isNotBlank() }.associateBy { it.mac.lowercase() }
    val uniqueUsageNames = usage.groupBy { it.name }.filterValues { it.size == 1 }.mapValues { it.value.single() }
    val costsByMac = costs.mapNotNull { cost ->
        val mac = cost.mac.takeIf { it.isNotBlank() } ?: uniqueUsageNames[cost.name]?.mac
        mac?.takeIf { it.isNotBlank() }?.lowercase()?.let { it to cost }
    }.toMap()
    val macs = usageByMac.keys + costsByMac.keys
    val totalGb = usageByMac.values.sumOf { it.gb }
    return macs.map { mac ->
        val usageRow = usageByMac[mac]
        val costRow = costsByMac[mac]
        val device = devicesByMac[mac]
        val gb = usageRow?.gb ?: costRow?.gb ?: 0.0
        DeviceRanking(
            mac = device?.mac ?: usageRow?.mac ?: costRow?.mac?.takeIf { it.isNotBlank() } ?: mac,
            label = device?.alias?.ifBlank { device.lastSeenName }?.ifBlank { null } ?: usageRow?.name?.ifBlank { null } ?: costRow?.name?.ifBlank { null } ?: Format.bidi(mac),
            gb = gb,
            toman = costRow?.toman ?: 0,
            share = costRow?.share?.takeIf { it > 0 } ?: if (totalGb > 0) gb / totalGb * 100 else 0.0,
        )
    }
}

private val routerDateTime = DateTimeFormatter.ofPattern("yyyy-MM-dd HH:mm")
private val tehranZone = ZoneId.of("Asia/Tehran")

private fun parseRouterTs(value: String): Long? = runCatching {
    if (value.length == 10) LocalDate.parse(value).atStartOfDay(tehranZone).toInstant().toEpochMilli()
    else LocalDateTime.parse(value, routerDateTime).atZone(tehranZone).toInstant().toEpochMilli()
}.getOrNull()

private fun List<SampleEntity>.toTimedValues() = map { ChartMath.TimedValue(it.ts, it.value) }

/** Bottom sheet editor for one device: alias, owner, category, visibility, watch. */
@Composable
private fun DeviceEditorSheet(vm: XirouterViewModel, dev: DeviceSettingsEntity, onClose: () -> Unit) {
    val personRows by vm.persons.collectAsStateWithLifecycle()
    var alias by remember { mutableStateOf(dev.alias) }
    var category by remember { mutableStateOf(dev.category) }
    var note by remember { mutableStateOf(dev.note) }
    var owner by remember { mutableStateOf(dev.ownerPersonId ?: "") }
    var hide by remember { mutableStateOf(dev.hideFromLedger) }
    var watch by remember { mutableStateOf(dev.watched) }
    var renameTarget by remember { mutableStateOf("") }
    val people = personRows.filter { !it.implicit && !it.archived }
    var ownershipRemoval by remember { mutableStateOf(false) }

    val scroll = rememberScrollState()
    Sheet(open = true, onDismiss = onClose, side = SheetSide.Left, modifier = Modifier.imePadding(), label = "ویرایش دستگاه") {
        Column(Modifier.fillMaxWidth().fillMaxHeight().verticalScroll(scroll), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        SheetHeader("دستگاه", description = Format.bidi(dev.mac))
        FieldLabel("نام نمایشی")
        Input(value = alias, onValueChange = { alias = it }, placeholder = "مثلاً گوشی پارسا", label = "نام نمایشی")
        FieldLabel("دسته")
        Input(value = category, onValueChange = { category = it }, placeholder = "مثلاً موبایل", label = "دسته")
        FieldLabel("یادداشت")
        Input(value = note, onValueChange = { note = it }, placeholder = "یادداشت اختیاری", label = "یادداشت")
        FieldLabel("مالک")
        Select(
            selectedValue = owner,
            onValueChange = { owner = it },
            options = listOf(SelectOption("", "بدون مالک (فاکتور نمی‌شود)")) + people.map { SelectOption(it.id, it.name) },
            placeholder = "انتخاب مالک",
            label = "مالک دستگاه",
            modifier = Modifier.fillMaxWidth(),
        )
        Row(Modifier.fillMaxWidth().padding(top = 8.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("در دفترحساب نمایش داده شود", variant = TextVariant.Muted, modifier = Modifier.weight(1f))
            Toggle(checked = !hide, onCheckedChange = { hide = !it })
        }
        Row(Modifier.fillMaxWidth().padding(top = 4.dp), verticalAlignment = Alignment.CenterVertically) {
            Text("تحت نظر (هشدار دستگاه جدید)", variant = TextVariant.Muted, modifier = Modifier.weight(1f))
            Toggle(checked = watch, onCheckedChange = { watch = it })
        }
        Row(Modifier.fillMaxWidth().padding(top = 12.dp), horizontalArrangement = Arrangement.spacedBy(8.dp)) {
            Button(onClick = {
                if (dev.ownerPersonId != null && owner != dev.ownerPersonId) ownershipRemoval = true else {
                    vm.setDeviceAlias(dev.mac, alias)
                    vm.setDeviceCategory(dev.mac, category)
                    vm.setDeviceNote(dev.mac, note)
                    vm.setDeviceOwner(dev.mac, owner.ifBlank { null })
                    vm.setHideFromLedger(dev.mac, hide)
                    vm.setWatch(dev.mac, watch)
                    onClose()
                }
            }, modifier = Modifier.weight(1f)) { Text("ذخیره") }
            Button(onClick = onClose, variant = ButtonVariant.Ghost, modifier = Modifier.weight(1f)) { Text("انصراف") }
        }
        FieldLabel("نام دستگاه در روتر")
        Input(value = renameTarget, onValueChange = { renameTarget = it }, placeholder = alias.ifBlank { "نام در روتر" }, label = "نام دستگاه در روتر")
        Button(
            onClick = { vm.renameDevice(dev.mac, renameTarget.ifBlank { alias }) },
            enabled = renameTarget.isNotBlank() || alias.isNotBlank(),
            variant = ButtonVariant.Secondary,
            modifier = Modifier.fillMaxWidth(),
        ) { Text("تغییر نام در روتر") }
        Spacer(Modifier.height(24.dp))
        }
    }
    if (ownershipRemoval) DestructiveActionDialog(
        title = "تغییر مالکیت دستگاه؟",
        description = "مالکیت فعلی حذف میشود و سابقهٔ آن در دفترحساب حفظ خواهد شد.",
        configuredPin = vm.store.lockPin.takeIf { vm.store.appLockConfigured() }.orEmpty(),
        onDismiss = { ownershipRemoval = false },
        onConfirm = {
            vm.setDeviceAlias(dev.mac, alias); vm.setDeviceCategory(dev.mac, category); vm.setDeviceNote(dev.mac, note)
            vm.setDeviceOwner(dev.mac, owner.ifBlank { null }); vm.setHideFromLedger(dev.mac, hide); vm.setWatch(dev.mac, watch)
            ownershipRemoval = false; onClose()
        },
    )
}

@Composable
private fun FieldLabel(text: String) = Text(text, variant = TextVariant.Small, style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold))

/** Global Device workspace. Selection is keyed by MAC, so filtering never drops selected Devices. */
@Composable
fun DeviceWorkspaceScreen(vm: XirouterViewModel, initialPersonId: String? = null) {
    val devices by vm.devices.collectAsStateWithLifecycle()
    val personRows by vm.persons.collectAsStateWithLifecycle()
    val online = vm.clients.value?.clients.orEmpty().mapTo(mutableSetOf()) { it.mac.lowercase() }
    var query by remember { mutableStateOf("") }
    var person by remember { mutableStateOf(initialPersonId ?: "all") }
    var category by remember { mutableStateOf("all") }
    var state by remember { mutableStateOf("all") }
    var selected by remember { mutableStateOf(emptySet<String>()) }
    var bulkOwner by remember { mutableStateOf("") }
    var bulkCategory by remember { mutableStateOf("") }
    var confirming by remember { mutableStateOf(false) }
    DisposableEffect(Unit) { onDispose { selected = emptySet() } }
    val people = personRows.filter { !it.archived && !it.implicit }
    val owners = personRows.associateBy { it.id }
    val categories = devices.map { it.category }.filter { it.isNotBlank() }.distinct().sorted()
    val visible = devices.filter { d ->
        val label = d.alias.ifBlank { d.lastSeenName }
        (query.isBlank() || listOf(label, d.mac, d.note).any { it.contains(query, true) }) &&
            (person == "all" || person == "unbilled" && d.ownerPersonId == null || d.ownerPersonId == person) &&
            (category == "all" || d.category == category) &&
            (state == "all" || state == "online" && d.mac.lowercase() in online || state == "offline" && d.mac.lowercase() !in online)
    }
    LazyColumn(Modifier.fillMaxWidth()) {
        item {
            Column(Modifier.padding(horizontal = RikkaTheme.spacing.lg), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                Input(query, { query = it }, placeholder = "جستجوی نام، MAC یا یادداشت", label = "جستجوی دستگاه", clearable = true)
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Select(person, { person = it }, listOf(SelectOption("all", "همه اشخاص"), SelectOption("unbilled", "بدون مالک")) + people.map { SelectOption(it.id, it.name) }, Modifier.weight(1f), label = "شخص")
                    Select(category, { category = it }, listOf(SelectOption("all", "همه دستهها")) + categories.map { SelectOption(it, it) }, Modifier.weight(1f), label = "دسته")
                }
                Select(state, { state = it }, listOf(SelectOption("all", "آنلاین و آفلاین"), SelectOption("online", "آنلاین"), SelectOption("offline", "آفلاین")), label = "وضعیت")
                Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                    Button({ selected = selected + visible.map { it.mac } }, variant = ButtonVariant.Secondary, modifier = Modifier.weight(1f)) { Text("انتخاب همهٔ نمایان") }
                    Button({ selected = emptySet() }, variant = ButtonVariant.Ghost, modifier = Modifier.weight(1f)) { Text("پاککردن (${Format.faNum(selected.size.toString())})") }
                }
            }
        }
        items(visible, key = { it.mac }) { d ->
            val chosen = d.mac in selected
            Card(onClick = { selected = if (chosen) selected - d.mac else selected + d.mac }, modifier = Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp)) {
                Row(Modifier.padding(RikkaTheme.spacing.md), verticalAlignment = Alignment.CenterVertically) {
                    zed.rainxch.rikkaui.components.ui.checkbox.Checkbox(chosen, { on -> selected = if (on) selected + d.mac else selected - d.mac })
                    Column(Modifier.weight(1f).padding(horizontal = 8.dp)) {
                        Text(d.alias.ifBlank { d.lastSeenName }.ifBlank { Format.bidi(d.mac) }, style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold))
                        Text("مالک: ${d.ownerPersonId?.let { owners[it]?.name } ?: "بدون مالک"} · ${if (d.mac.lowercase() in online) "آنلاین" else "آفلاین"}${d.category.takeIf { it.isNotBlank() }?.let { " · $it" }.orEmpty()}", variant = TextVariant.Muted)
                    }
                }
            }
        }
        if (selected.isNotEmpty()) item {
            Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 12.dp)) {
                Text("عملیات گروهی روی ${Format.faNum(selected.size.toString())} دستگاه", variant = TextVariant.H4)
                Select(bulkOwner, { bulkOwner = it }, listOf(SelectOption("", "مالک را تغییر نده"), SelectOption("__remove__", "حذف مالکیت")) + people.map { SelectOption(it.id, it.name) }, Modifier.padding(top = 8.dp), label = "مالک جدید")
                Input(bulkCategory, { bulkCategory = it }, placeholder = "خالی یعنی بدون تغییر", label = "دستهٔ جدید", modifier = Modifier.padding(top = 8.dp))
                Button({ confirming = true }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp)) { Text("اعمال اتمیک") }
            }
        }
    }
    if (confirming) DestructiveActionDialog(
        "اعمال تغییر گروهی؟", "همه تغییرها با یک تاریخ مؤثر تهران و یک بازسازی دفترحساب ثبت میشوند.",
        vm.store.lockPin.takeIf { vm.store.appLockConfigured() }.orEmpty(), { confirming = false }, {
            val ownerChange = when (bulkOwner) { "" -> BulkValue.Keep; "__remove__" -> BulkValue.Set(null); else -> BulkValue.Set(bulkOwner) }
            vm.bulkDevices(BulkDeviceChange(selected, ownerPersonId = ownerChange, category = bulkCategory.takeIf { it.isNotBlank() }))
            selected = emptySet(); confirming = false
        },
    )
}