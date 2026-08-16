package ir.parsavisions.xirouter.ui

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.KeyboardArrowLeft
import androidx.compose.material.icons.filled.PersonOff
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.parsavisions.xirouter.Format
import ir.parsavisions.xirouter.MonthAttribution
import ir.parsavisions.xirouter.Store
import ir.parsavisions.xirouter.XirouterViewModel
import ir.parsavisions.xirouter.jalaliMonthLabel
import ir.parsavisions.xirouter.jalaliOf
import ir.parsavisions.xirouter.tehranDay
import zed.rainxch.rikkaui.components.ui.alert.Alert
import zed.rainxch.rikkaui.components.ui.alert.AlertTitle
import zed.rainxch.rikkaui.components.ui.button.Button
import zed.rainxch.rikkaui.components.ui.button.ButtonVariant
import zed.rainxch.rikkaui.components.ui.card.Card
import zed.rainxch.rikkaui.components.ui.icon.Icon
import zed.rainxch.rikkaui.components.ui.button.IconButton
import zed.rainxch.rikkaui.components.ui.text.Text
import zed.rainxch.rikkaui.components.ui.text.TextVariant
import zed.rainxch.rikkaui.foundation.RikkaTheme

/** Dashboard: explicit freshness states and user-ordered, user-visible cards. */
@Composable
fun HomeScreen(vm: XirouterViewModel) {
    LaunchedEffect(Unit) { vm.refreshAll() }
    val balance = vm.balance.value
    val status = vm.status.value
    val usageRows = vm.usage.value?.rows.orEmpty()
    val entriesByMonth by vm.entriesByMonth.collectAsStateWithLifecycle()
    val personRows by vm.persons.collectAsStateWithLifecycle()
    val devices by vm.devices.collectAsStateWithLifecycle()
    val today = jalaliOf(tehranDay(System.currentTimeMillis()))
    val entries = entriesByMonth[MonthAttribution.key(today.year, today.month)].orEmpty()
    val people = personRows.associateBy { it.id }
    val owners = devices.associate { it.mac to it.ownerPersonId }
    val ranking = usageRows.groupBy { owners[it.mac] }.mapNotNull { (personId, rows) ->
        people[personId]?.name?.let { it to rows.sumOf { row -> row.gb } }
    }.sortedByDescending { it.second }.take(3)
    val unpaid = entries.count { it.owedToman > it.paidToman }
    val hidden = vm.store.dashboardHidden
    val cards = vm.store.dashboardOrder.filterNot { it in hidden }
    var proxyDialog by remember { mutableStateOf(false) }

    LazyColumn(Modifier.fillMaxWidth()) {
        item {
            Hero(vm, today.year, today.month, usageRows.sumOf { it.gb }, onProxyClick = { proxyDialog = true })
        }
        item {
            // Dashboard v2 quick actions: one tap to the operations people need.
            Row(Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = RikkaTheme.spacing.xs)) {
                Button(onClick = vm::refreshAll, variant = ButtonVariant.Outline, modifier = Modifier.weight(1f)) { Text("بهروزرسانی", variant = TextVariant.Small) }
                Spacer(Modifier.width(8.dp))
                Button(onClick = { proxyDialog = true }, variant = ButtonVariant.Outline, modifier = Modifier.weight(1f)) { Text("پروکسی", variant = TextVariant.Small) }
                Spacer(Modifier.width(8.dp))
                Button(onClick = { vm.nav.tab(XRoute.Ledger) }, variant = ButtonVariant.Outline, modifier = Modifier.weight(1f)) { Text("دفترچه", variant = TextVariant.Small) }
            }
        }
        item {
            when {
                vm.loading.value && vm.lastUpdate.value == 0L -> Alert(Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg)) {
                    AlertTitle("در حال دریافت اطلاعات روتر…")
                }
                // Router failures use the single shell-level ErrorCard policy.
            }
        }
        cards.forEach { card ->
            when (card) {
                "collection" -> if (unpaid > 0) item(key = card) {
                    Card(onClick = { vm.nav.tab(XRoute.Ledger) }, modifier = Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = RikkaTheme.spacing.sm)) {
                        Row(Modifier.padding(RikkaTheme.spacing.lg), verticalAlignment = Alignment.CenterVertically) {
                            Icon(Icons.Filled.PersonOff, null, tint = StatusColors.warning); Spacer(Modifier.width(10.dp))
                            Column(Modifier.weight(1f)) {
                                Text("وصول ناقص برای ${Format.faDigits("$unpaid")} شخص", variant = TextVariant.H4)
                                Text("ماه جاری هنوز تسویه نشده است", variant = TextVariant.Muted)
                            }
                            Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, null)
                        }
                    }
                }
                "ranking" -> {
                    item(key = "$card-title") { SectionTitle("بیشترین مصرف امروز") }
                    if (vm.loading.value && ranking.isEmpty()) items(3) { SkeletonBlock(44, Modifier.padding(horizontal = RikkaTheme.spacing.lg)) }
                    else if (ranking.isEmpty()) item(key = "$card-empty") {
                        EmptyState(Icons.Filled.PersonOff, "مصرف شخصی ثبت نشده", "دستگاهها را به شخص نسبت دهید تا رتبهبندی نمایش داده شود.", Modifier.padding(horizontal = RikkaTheme.spacing.lg))
                    } else items(ranking, key = { it.first }) { (name, gb) ->
                        Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp)) {
                            RankRow(name, "${Format.gbValue(gb)} GB", (gb / ranking.first().second).toFloat())
                        }
                    }
                }
                "live" -> item(key = card) {
                    Card(onClick = { vm.nav.tab(XRoute.Live) }, modifier = Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = RikkaTheme.spacing.sm)) {
                        Row(Modifier.padding(RikkaTheme.spacing.lg), verticalAlignment = Alignment.CenterVertically) {
                            StatusPill("LIVE", StatusColors.info); Spacer(Modifier.width(10.dp))
                            Column(Modifier.weight(1f)) { Text("پهنای باند زنده", variant = TextVariant.H4); Text("سرعت کل و هر دستگاه", variant = TextVariant.Muted) }
                            Icon(Icons.AutoMirrored.Filled.KeyboardArrowLeft, null)
                        }
                    }
                }
                "link" -> item(key = card) {
                    val link = vm.link.value
                    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = RikkaTheme.spacing.sm)) {
                        Column(Modifier.padding(RikkaTheme.spacing.lg)) {
                            Row(verticalAlignment = Alignment.CenterVertically) {
                                StatusPill(if (link == null) "—" else link.signalLabel, if ((link?.signal ?: 0) >= 3) StatusColors.up else StatusColors.warning)
                                Spacer(Modifier.width(10.dp))
                                Text("اتصال ۴G/۵G", variant = TextVariant.H4)
                            }
                            DetailRow("اپراتور", link?.operator?.takeIf { it.isNotBlank() } ?: "—")
                            DetailRow("فنّاوری", link?.tech?.takeIf { it.isNotBlank() } ?: "—")
                            link?.rsrp?.let { DetailRow("RSRP (LTE)", Format.faDigits("$it") + " dBm") }
                            link?.rsrp_5g?.let { DetailRow("RSRP (5G)", Format.faDigits("$it") + " dBm") }
                            if (link?.band?.isNotBlank() == true) DetailRow("باند", link.band)
                            DetailRow("PLMN", link?.plmn?.takeIf { it.isNotBlank() } ?: "—")
                            link?.flow?.let { f ->
                                DetailRow("داده امروز", "${Format.faDigits(Format.gbValue(f.dl / (1024.0 * 1024.0)))} ↓ / ${Format.faDigits(Format.gbValue(f.ul / (1024.0 * 1024.0)))} ↑")
                            }
                        }
                    }
                }
                "forecast" -> item(key = card) {
                    val insights = vm.dashboardInsights()
                    Card(modifier = Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = RikkaTheme.spacing.sm)) {
                        Column(Modifier.padding(RikkaTheme.spacing.lg)) {
                            Text("پیشبینی پایان ماه", variant = TextVariant.H4)
                            Text(vm.dashboardForecast(), variant = TextVariant.P, style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold))
                            if (insights.isNotEmpty()) {
                                Spacer(Modifier.height(8.dp))
                                Text("«برآورد»", variant = TextVariant.Small)
                                insights.forEach { Text(it, variant = TextVariant.Muted) }
                            }
                        }
                    }
                }
                "metrics" -> {
                    item(key = "$card-title") { SectionTitle("شاخصها") }
                    item(key = card) {
                        Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
                            DetailRow("آپتایم", status?.uptime ?: "—")
                            status?.ram?.let { DetailRow("رم", "${Format.faNum("${it.used_mb ?: 0}")} / ${Format.faNum("${it.total_mb ?: 0}")} MB") }
                            DetailRow("دمای روتر", status?.temp_c?.let { Format.faDigits("$it") + "°C" } ?: "—")
                            DetailRow("حافظه", status?.disk?.let { "${Format.faDigits("${it.pct ?: 0}")}٪ (${it.free ?: "—"} آزاد)" } ?: "—")
                        }
                    }
                }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }

    if (proxyDialog) DestructiveActionDialog(
        title = "تغییر گره پروکسی؟",
        description = "گره فعال تغییر میکند و ممکن است اتصال لحظهای قطع شود.",
        configuredPin = vm.store.lockPin.takeIf { vm.store.appLockConfigured() }.orEmpty(),
        onDismiss = { proxyDialog = false },
        onConfirm = {
            proxyDialog = false
            val next = if (status?.proxy?.node == "hysteria2") "REALITY-443-parsa" else "hysteria2"
            vm.switchProxy(next) {}
        },
    )
}

@Composable
private fun Hero(vm: XirouterViewModel, year: Int, month: Int, usageGb: Double, onProxyClick: () -> Unit) {
    val main = vm.balance.value?.main
    val status = vm.status.value
    BoxWithConstraints(
        Modifier.fillMaxWidth().background(Brush.verticalGradient(listOf(RikkaTheme.colors.primary.copy(alpha = .22f), RikkaTheme.colors.background))).padding(RikkaTheme.spacing.lg),
    ) {
        val compact = maxWidth < 360.dp || LocalDensity.current.fontScale > 1.2f
        Column {
            if (compact) {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    GaugeRing(main?.pct ?: 0, label = "${Format.faDigits("${main?.pct ?: 0}")}٪", size = 64)
                    Spacer(Modifier.width(RikkaTheme.spacing.md)); BalanceText(main?.remain ?: 0.0, main?.quota ?: 0, year, month, Modifier.weight(1f))
                    IconButton(Icons.Filled.Refresh, "بهروزرسانی", onClick = vm::refreshAll)
                }
                Spacer(Modifier.height(8.dp))
                ProxyAndDevices(vm, onProxyClick, stacked = true)
            } else {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    GaugeRing(main?.pct ?: 0, label = "${Format.faDigits("${main?.pct ?: 0}")}٪", size = 72)
                    Spacer(Modifier.width(RikkaTheme.spacing.md)); BalanceText(main?.remain ?: 0.0, main?.quota ?: 0, year, month, Modifier.weight(1f))
                    IconButton(Icons.Filled.Refresh, "بهروزرسانی", onClick = vm::refreshAll)
                }
                ProxyAndDevices(vm, onProxyClick, stacked = false)
            }
            vm.balance.value?.drain?.takeIf { it.isNotBlank() }?.let { Text("روند: $it", variant = TextVariant.Small, modifier = Modifier.padding(top = 6.dp)) }
            Column(Modifier.padding(top = RikkaTheme.spacing.md)) {
                Text("امروز · ${Format.gbValue(usageGb)} GB", variant = TextVariant.P)
                Text("حافظه ${status?.disk?.pct ?: "—"}٪ · بار ${status?.load ?: "—"} · دما ${status?.temp_c ?: "—"}°C", variant = TextVariant.Muted)
            }
            if (vm.lastUpdate.value > 0) Text(freshness(vm.lastUpdate.value), variant = TextVariant.Small, modifier = Modifier.padding(top = 4.dp))
        }
    }
}

@Composable private fun BalanceText(remain: Double, quota: Int, year: Int, month: Int, modifier: Modifier) = Column(modifier) {
    FigureText("${Format.gbValue(remain)} GB", variant = TextVariant.H3, fontWeight = FontWeight.Bold)
    Text("از ${Format.gbValue(quota.toDouble())} گیگابایت · ${jalaliMonthLabel(year, month)}", variant = TextVariant.Muted)
}

@Composable private fun ProxyAndDevices(vm: XirouterViewModel, onProxyClick: () -> Unit, stacked: Boolean) {
    val proxy = vm.status.value?.proxy
    @Composable fun Proxy() = Button(onClick = onProxyClick, variant = ButtonVariant.Ghost) {
        StatusPill(if (proxy?.state == "up") "آنلاین" else "قطع", if (proxy?.state == "up") StatusColors.up else StatusColors.down)
        Spacer(Modifier.width(6.dp)); Text("پروکسی · ${proxy?.node ?: "—"}", variant = TextVariant.Muted)
    }
    if (stacked) Column { Proxy(); Text("دستگاهها: ${vm.clients.value?.clients?.size ?: 0}", variant = TextVariant.Muted) }
    else Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { Proxy(); Spacer(Modifier.weight(1f)); Text("دستگاهها: ${vm.clients.value?.clients?.size ?: 0}", variant = TextVariant.Muted) }
}

private fun freshness(ts: Long): String = try {
    val fmt = java.time.format.DateTimeFormatter.ofPattern("HH:mm")
    "آخرین دریافت موفق: " + fmt.withZone(java.time.ZoneId.of("Asia/Tehran")).format(java.time.Instant.ofEpochMilli(ts))
} catch (_: Exception) { "" }
