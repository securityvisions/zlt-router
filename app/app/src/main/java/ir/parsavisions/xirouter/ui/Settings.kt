package ir.parsavisions.xirouter.ui

import android.content.Intent
import android.net.Uri
import android.provider.Settings
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ArrowDownward
import androidx.compose.material.icons.filled.ArrowUpward
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.unit.dp
import ir.parsavisions.xirouter.DiagnosticStore
import ir.parsavisions.xirouter.Format
import ir.parsavisions.xirouter.Store
import ir.parsavisions.xirouter.UiPreferences
import ir.parsavisions.xirouter.XirouterViewModel
import ir.parsavisions.xirouter.jalaliOf
import ir.parsavisions.xirouter.tehranDay
import kotlinx.coroutines.launch
import zed.rainxch.rikkaui.components.ui.alertdialog.AlertDialog
import zed.rainxch.rikkaui.components.ui.alertdialog.AlertDialogHeader
import zed.rainxch.rikkaui.components.ui.button.Button
import zed.rainxch.rikkaui.components.ui.button.ButtonVariant
import zed.rainxch.rikkaui.components.ui.button.IconButton
import zed.rainxch.rikkaui.components.ui.input.Input
import zed.rainxch.rikkaui.components.ui.select.Select
import zed.rainxch.rikkaui.components.ui.select.SelectOption
import zed.rainxch.rikkaui.components.ui.text.Text
import zed.rainxch.rikkaui.components.ui.text.TextVariant
import zed.rainxch.rikkaui.components.ui.toggle.Toggle
import zed.rainxch.rikkaui.components.ui.toast.LocalToastHostState
import zed.rainxch.rikkaui.foundation.RikkaTheme

/** Settings: every edited preference is held reactively and persisted immediately or explicitly. */
@Composable
fun SettingsScreen(vm: XirouterViewModel) {
    val store = vm.store
    var url by rememberSaveablePreference(store.baseUrl)
    var token by rememberSaveablePreference(store.token)
    var rate by remember { mutableStateOf(store.defaultRate.toString()) }
    var landing by remember { mutableStateOf(store.landingTab) }
    var navigation by remember { mutableStateOf(store.navigationOrder) }
    var liveInTabs by remember { mutableStateOf(store.liveInTabs) }
    var dashboardSizes by remember { mutableStateOf(store.dashboardSizes) }
    var notifications by remember { mutableStateOf(notificationValues(store)) }
    var packageThreshold by remember { mutableStateOf(store.packageAlertThresholdPct.toString()) }
    var lockEnabled by remember { mutableStateOf(store.appLockConfigured()) }
    var dashboardOrder by remember { mutableStateOf(store.dashboardOrder) }
    var dashboardHidden by remember { mutableStateOf(store.dashboardHidden) }
    var testUrl by remember { mutableStateOf("") }
    var testResult by remember { mutableStateOf<String?>(null) }
    var testing by remember { mutableStateOf(false) }
    var confirmReboot by remember { mutableStateOf(false) }
    var showLockSetup by remember { mutableStateOf(false) }
    val context = LocalContext.current
    val scope = rememberCoroutineScope()
    val toast = LocalToastHostState.current
    val diagnostics = remember(context) { DiagnosticStore(context) }
    val today = jalaliOf(tehranDay(System.currentTimeMillis()))
    val csvLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("text/csv")) { uri ->
        if (uri != null) scope.launch { toast.show(if (Export.writeCsv(context, uri, vm.yearCsv(today.year))) "خروجی سال ذخیره شد" else "خروجی نوشته نشد") }
    }
    val supportLauncher = rememberLauncherForActivityResult(ActivityResultContracts.CreateDocument("application/zip")) { uri ->
        if (uri != null) scope.launch { toast.show(if (Export.writeBytes(context, uri, diagnostics.bundle())) "Support bundle ذخیره شد" else "Support bundle نوشته نشد") }
    }
    fun feedback(message: String) { scope.launch { toast.show(message) } }

    LazyColumn(Modifier.fillMaxWidth()) {
        item { SectionTitle("اتصال") }
        item { Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
            FieldLabel("آدرس Router API")
            Input(url, { url = it }, placeholder = "http://192.168.1.1/cgi-bin/routerapi.sh", modifier = Modifier.fillMaxWidth())
            FieldLabel("توکن دسترسی", Modifier.padding(top = 8.dp))
            Input(token, { token = it }, placeholder = "توکن", modifier = Modifier.fillMaxWidth())
            Button(onClick = { store.baseUrl = url.trim(); store.token = token.trim(); vm.refreshAll(); feedback("تنظیمات اتصال ذخیره شد") }, enabled = url.isNotBlank() && token.isNotBlank(), modifier = Modifier.padding(top = 8.dp)) { Text("ذخیره و بهروزرسانی") }
        } }
        item { SectionTitle("قیمت") }
        item { Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
            ResponsiveSetting("نرخ پیشفرض هر گیگابایت (تومان)") {
                Input(rate, { rate = it }, placeholder = "7700", keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), modifier = Modifier.fillMaxWidth())
            }
            Button(onClick = { val v = Format.parseAmount(rate)?.toLong()?.coerceAtLeast(0) ?: return@Button; vm.setDefaultRate(v); rate = v.toString(); feedback("نرخ ذخیره شد") }, modifier = Modifier.padding(top = 8.dp)) { Text("ذخیره نرخ") }
        } }
        item { SectionTitle("ظاهر و خوانایی") }
        item { Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
            Text("نمای دلخواه شما", variant = TextVariant.H4)
            Text("رنگ، تراکم و حرکت در سراسر برنامه هماهنگ میماند.", variant = TextVariant.Muted, modifier = Modifier.padding(bottom = 12.dp))
            ResponsiveSetting("پیشتنظیم") { Select(store.appearancePreset, { vm.updateAppearance { appearancePreset = it } }, listOf(SelectOption("calm", "آرام"), SelectOption("vivid", "زنده"), SelectOption("focused", "متمرکز")), Modifier.fillMaxWidth()) }
            ResponsiveSetting("حالت نمایش", Modifier.padding(top = 8.dp)) { Select(store.themeMode, { vm.updateAppearance { themeMode = it } }, listOf(SelectOption("system", "همراه با سیستم"), SelectOption("light", "روشن"), SelectOption("dark", "تیره")), Modifier.fillMaxWidth()) }
            ResponsiveSetting("تراکم", Modifier.padding(top = 8.dp)) { Select(store.uiDensity, { vm.updateAppearance { uiDensity = it } }, listOf(SelectOption("comfortable", "راحت"), SelectOption("compact", "فشرده")), Modifier.fillMaxWidth()) }
            ResponsiveSetting("رنگ تأکیدی", Modifier.padding(top = 8.dp)) { Select(store.accent, { vm.updateAppearance { accent = it } }, listOf(SelectOption("green", "سبز"), SelectOption("blue", "آبی"), SelectOption("violet", "بنفش"), SelectOption("orange", "نارنجی"), SelectOption("rose", "رز")), Modifier.fillMaxWidth()) }
            ToggleSetting("کاهش حرکت", store.reducedMotion) { vm.updateAppearance { reducedMotion = it } }
            ResponsiveSetting("سبک نمودار", Modifier.padding(top = 8.dp)) { Select(store.chartStyle, { store.chartStyle = it }, listOf(SelectOption("line", "خطی"), SelectOption("area", "سطحی"), SelectOption("bars", "میلهای")), Modifier.fillMaxWidth()) }
            ResponsiveSetting("جزئیات نمودار", Modifier.padding(top = 8.dp)) { Select(store.chartDetail, { store.chartDetail = it }, listOf(SelectOption("simple", "ساده"), SelectOption("detailed", "کامل")), Modifier.fillMaxWidth()) }
        } }
        item { SectionTitle("پیمایش اصلی") }
        item { Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
            ToggleSetting("نمایش زنده در نوار پایین", liveInTabs) { value -> liveInTabs = value; store.liveInTabs = value; navigation = UiPreferences.navigation(navigation, value); store.navigationOrder = navigation }
            navigation.forEachIndexed { index, id ->
                val label = navigationLabel(id)
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Text(label, modifier = Modifier.weight(1f))
                    IconButton(Icons.Filled.ArrowUpward, "انتقال $label به بالا", enabled = index > 0, onClick = { navigation = navigation.moved(index, index - 1); store.navigationOrder = navigation })
                    IconButton(Icons.Filled.ArrowDownward, "انتقال $label به پایین", enabled = index < navigation.lastIndex, onClick = { navigation = navigation.moved(index, index + 1); store.navigationOrder = navigation })
                }
            }
            ResponsiveSetting("صفحهٔ شروع", Modifier.padding(top = 8.dp)) { Select(landing, { landing = it; vm.setLandingTab(it) }, navigation.map { SelectOption(it, navigationLabel(it)) }, Modifier.fillMaxWidth()) }
            Button({ navigation = UiPreferences.navigation(emptyList(), liveInTabs); store.navigationOrder = navigation }, variant = ButtonVariant.Secondary, modifier = Modifier.padding(top = 8.dp)) { Text("بازنشانی پیمایش") }
            Text("تنظیمات همیشه از بالای هر صفحه در دسترس است.", variant = TextVariant.Small, modifier = Modifier.padding(top = 6.dp))
        } }
        item { SectionTitle("چیدمان Dashboard") }
        item { Row(Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
            listOf("daily" to "روزانه", "billing" to "صورتحساب", "troubleshooting" to "عیبیابی").forEach { (id, label) -> Button({ store.applyDashboardPreset(id); dashboardOrder = store.dashboardOrder; dashboardHidden = store.dashboardHidden; dashboardSizes = store.dashboardSizes }, variant = ButtonVariant.Secondary, modifier = Modifier.weight(1f)) { Text(label, variant = TextVariant.Small) } }
        } }
        item { SectionTitle("کارتهای Dashboard") }
        item { Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
            dashboardOrder.forEachIndexed { index, id ->
                val label = dashboardLabel(id)
                Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) {
                    Toggle(checked = id !in dashboardHidden, onCheckedChange = { visible -> dashboardHidden = if (visible) dashboardHidden - id else dashboardHidden + id; store.dashboardHidden = dashboardHidden })
                    Column(Modifier.weight(1f).padding(horizontal = 8.dp)) {
                        Text(label)
                        Select(dashboardSizes[id] ?: "medium", { size -> dashboardSizes = dashboardSizes + (id to size); store.dashboardSizes = dashboardSizes }, listOf(SelectOption("small", "کوچک"), SelectOption("medium", "متوسط"), SelectOption("full", "کامل")), Modifier.fillMaxWidth())
                    }
                    IconButton(Icons.Filled.ArrowUpward, "انتقال $label به بالا", enabled = index > 0, onClick = { dashboardOrder = dashboardOrder.moved(index, index - 1); store.dashboardOrder = dashboardOrder })
                    IconButton(Icons.Filled.ArrowDownward, "انتقال $label به پایین", enabled = index < dashboardOrder.lastIndex, onClick = { dashboardOrder = dashboardOrder.moved(index, index + 1); store.dashboardOrder = dashboardOrder })
                }
            }
            Text("پیشنمایش زنده", variant = TextVariant.H4, modifier = Modifier.padding(top = 12.dp))
            Text(dashboardOrder.filterNot { it in dashboardHidden }.joinToString("  •  ") { "${dashboardLabel(it)} (${sizeLabel(dashboardSizes[it])})" }, variant = TextVariant.Small, modifier = Modifier.padding(vertical = 6.dp))
            Button({ store.applyDashboardPreset(UiPreferences.DEFAULT_PRESET); dashboardOrder = store.dashboardOrder; dashboardHidden = store.dashboardHidden; dashboardSizes = store.dashboardSizes }, variant = ButtonVariant.Ghost) { Text("بازنشانی Dashboard") }
            Text("ترتیب، اندازه و نمایش کارتهای خانه بلافاصله ذخیره میشود.", variant = TextVariant.Small)
        } }
        item { SectionTitle("اعلانها") }
        item { Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
            notificationLabels.forEach { (key, label) -> ToggleSetting(label, notifications[key] == true) { value -> notifications = notifications + (key to value); setNotification(store, key, value) } }
            if (notifications["packages"] == true) ResponsiveSetting("آستانهٔ کمبود بسته (درصد)", Modifier.padding(top = 8.dp)) {
                Input(packageThreshold, { packageThreshold = it.filter(Char::isDigit).take(3); it.toIntOrNull()?.let { value -> store.packageAlertThresholdPct = value } }, placeholder = "20", keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.Number), modifier = Modifier.fillMaxWidth())
            }
            Text("هر بسته میتواند از صفحهٔ Data plan بیصدا شود یا آستانهٔ جداگانه داشته باشد.", variant = TextVariant.Small, modifier = Modifier.padding(top = 6.dp))
            if (android.os.Build.VERSION.SDK_INT >= 33 && store.notificationPermissionRequested && context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != android.content.pm.PackageManager.PERMISSION_GRANTED) {
                Text("اجازهٔ اعلان رد شده است؛ درخواست دوباره فقط از تنظیمات سیستم انجام میشود.", variant = TextVariant.Small, modifier = Modifier.padding(top = 8.dp))
                Button({ context.startActivity(Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:${context.packageName}"))) }, variant = ButtonVariant.Secondary, modifier = Modifier.padding(top = 6.dp)) { Text("بازکردن تنظیمات اعلان") }
            }
        } }
        item { SectionTitle("قفل برنامه") }
        item { Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
            ToggleSetting("فعال", lockEnabled) { requested ->
                if (requested) showLockSetup = true else { store.lockEnabled = false; lockEnabled = false; feedback("قفل غیرفعال شد") }
            }
            if (lockEnabled) Button({ showLockSetup = true }, variant = ButtonVariant.Secondary, modifier = Modifier.padding(top = 8.dp)) { Text("تغییر پین") }
            Text("عملیات مخرب و تغییر پروکسی به پین نیاز دارند.", variant = TextVariant.Small, modifier = Modifier.padding(top = 6.dp))
        } }
        item { SectionTitle("دادهها") }
        item { Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
            DetailRow("پشتیبانگیری خودکار", "بکاپ اندروید")
            DetailRow("وضعیت واردات از روتر", if (store.importedRouterHistory) "انجام شد" else "در اولین بهروزرسانی")
            Button({ csvLauncher.launch("xirouter-year-${today.year}.csv") }, modifier = Modifier.padding(top = 8.dp)) { Text("دریافت خروجی سال جاری (CSV)") }
            Text("Support bundle", variant = TextVariant.P, modifier = Modifier.padding(top = 16.dp))
            Text(diagnostics.preview(), variant = TextVariant.Small, modifier = Modifier.padding(top = 4.dp))
            Button({ supportLauncher.launch("xirouter-support.zip") }, variant = ButtonVariant.Secondary, modifier = Modifier.padding(top = 8.dp)) { Text("دریافت Support bundle") }
        } }
        item { SectionTitle("عملیات") }
        item { Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
            FieldLabel("آدرس برای تست از روتر")
            Input(testUrl, { testUrl = it }, placeholder = "https://google.com", modifier = Modifier.fillMaxWidth())
            Button(onClick = { testing = true; testResult = null; vm.testUrl(testUrl.trim()) { testResult = it; testing = false } }, enabled = testUrl.isNotBlank() && !testing, modifier = Modifier.padding(top = 6.dp)) { Text(if (testing) "در حال تست…" else "تست") }
            testResult?.let { Text("نتیجه: \u2066$it\u2069", variant = TextVariant.Small, modifier = Modifier.padding(top = 6.dp)) }
            Spacer(Modifier.height(12.dp)); DetailRow("گره فعلی", vm.status.value?.proxy?.node?.let { "\u2066$it\u2069" } ?: "—")
            Button({ confirmReboot = true }, variant = ButtonVariant.Destructive, modifier = Modifier.padding(top = 8.dp)) { Text("ریاستارت روتر") }
        } }
        item { Spacer(Modifier.height(24.dp)) }
    }

    if (confirmReboot) DestructiveActionDialog("ریاستارت روتر؟", "حدود یک دقیقه اینترنت قطع میشود.", store.lockPin.takeIf { store.appLockConfigured() }.orEmpty(), { confirmReboot = false }) {
        confirmReboot = false; vm.reboot { feedback(if (it) "فرمان ریاستارت ارسال شد" else "فرمان ریاستارت ناموفق بود") }
    }
    if (showLockSetup) LockSetupDialog(store.lockPin, onDismiss = { showLockSetup = false }) { pin ->
        if (store.configureAppLock(pin)) { lockEnabled = true; showLockSetup = false; feedback("پین ذخیره و قفل فعال شد") } else feedback("پین ذخیره نشد")
    }
}

@Composable private fun LockSetupDialog(current: String, onDismiss: () -> Unit, onSave: (String) -> Unit) {
    var pin by remember { mutableStateOf("") }
    AlertDialog(open = true, onDismiss = onDismiss, onConfirm = {}, label = "پین قفل", showDefaultActions = false, content = {
        Column {
            AlertDialogHeader("پین قفل", description = "پین ۱ تا ۸ رقمی را وارد کنید. تا ذخیرهٔ موفق، قفل فعال نمیشود.")
            FieldLabel(if (current.isBlank()) "پین جدید" else "پین جدید (برای تغییر)", Modifier.padding(top = 8.dp))
            Input(pin, { value -> if (value.length <= 8 && value.all(Char::isDigit)) pin = value }, placeholder = "پین", keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword), visualTransformation = PasswordVisualTransformation(), modifier = Modifier.fillMaxWidth())
            Row(Modifier.fillMaxWidth().padding(top = 8.dp), horizontalArrangement = Arrangement.End) {
                Button(onDismiss, variant = ButtonVariant.Ghost) { Text("انصراف") }; Spacer(Modifier.width(8.dp)); Button({ onSave(pin) }, enabled = pin.isNotBlank()) { Text("ذخیره و فعالسازی") }
            }
        }
    })
}

@Composable private fun ResponsiveSetting(label: String, modifier: Modifier = Modifier, content: @Composable () -> Unit) = BoxWithConstraints(modifier.fillMaxWidth()) {
    val compact = maxWidth < 340.dp || LocalDensity.current.fontScale > 1.2f
    if (compact) Column(Modifier.fillMaxWidth()) { FieldLabel(label); content() }
    else Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { Text(label, variant = TextVariant.Muted, modifier = Modifier.weight(1f)); Box(Modifier.weight(1f)) { content() } }
}
@Composable private fun FieldLabel(label: String, modifier: Modifier = Modifier) { Text(label, variant = TextVariant.Muted, modifier = modifier.padding(bottom = 4.dp)) }
@Composable private fun ToggleSetting(label: String, checked: Boolean, change: (Boolean) -> Unit) = Row(Modifier.fillMaxWidth().padding(vertical = 4.dp), verticalAlignment = Alignment.CenterVertically) { Text(label, modifier = Modifier.weight(1f)); Toggle(checked, change) }

@Composable private fun rememberSaveablePreference(initial: String) = androidx.compose.runtime.saveable.rememberSaveable { mutableStateOf(initial) }
private val notificationLabels = listOf("balance" to "موجودی", "packages" to "بستهها", "device" to "دستگاه جدید", "proxy" to "پروکسی", "disk" to "حافظه", "reboot" to "ریاستارت", "bill" to "قبض ماهانه", "drain" to "مصرف بالا")
private fun notificationValues(s: Store) = mapOf("balance" to s.notifBalance, "packages" to s.packageAlerts, "device" to s.notifDevice, "proxy" to s.notifProxy, "disk" to s.notifDisk, "reboot" to s.notifReboot, "bill" to s.notifBill, "drain" to s.notifDrain)
private fun setNotification(s: Store, key: String, value: Boolean) { when (key) { "balance" -> s.notifBalance = value; "packages" -> s.packageAlerts = value; "device" -> s.notifDevice = value; "proxy" -> s.notifProxy = value; "disk" -> s.notifDisk = value; "reboot" -> s.notifReboot = value; "bill" -> s.notifBill = value; "drain" -> s.notifDrain = value } }
private fun dashboardLabel(id: String) = when (id) { "collection" -> "هشدار وصول"; "ranking" -> "رتبهبندی اشخاص"; "metrics" -> "شاخصهای روتر"; "live" -> "پهنای باند زنده"; else -> id }
private fun navigationLabel(id: String) = when (id) { "home" -> "خانه"; "ledger" -> "حسابها"; "data" -> "بسته"; "live" -> "زنده"; else -> id }
private fun sizeLabel(id: String?) = when (id) { "small" -> "کوچک"; "full" -> "کامل"; else -> "متوسط" }
private fun <T> List<T>.moved(from: Int, to: Int): List<T> = toMutableList().apply { add(to, removeAt(from)) }
