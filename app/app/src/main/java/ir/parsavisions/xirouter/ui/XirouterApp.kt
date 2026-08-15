package ir.parsavisions.xirouter.ui

import androidx.activity.compose.BackHandler
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.statusBarsPadding
import androidx.compose.foundation.layout.navigationBarsPadding
import androidx.compose.foundation.layout.widthIn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Settings
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import androidx.compose.ui.platform.LocalContext
import ir.parsavisions.xirouter.DiagnosticKind
import ir.parsavisions.xirouter.DiagnosticRecord
import ir.parsavisions.xirouter.DiagnosticStore
import ir.parsavisions.xirouter.XirouterViewModel
import zed.rainxch.rikkaui.components.ui.button.IconButton
import zed.rainxch.rikkaui.components.ui.scaffold.Scaffold
import zed.rainxch.rikkaui.components.ui.text.Text
import zed.rainxch.rikkaui.components.ui.toast.LocalToastHostState
import zed.rainxch.rikkaui.components.ui.toast.ToastHost
import zed.rainxch.rikkaui.components.ui.toast.rememberToastHostState
import zed.rainxch.rikkaui.components.ui.topappbar.TopAppBar

/** App root: theme, entry gates, and the navigator. */
@Composable
fun XirouterApp(vm: XirouterViewModel) {
    vm.appearanceRevision.value
    val dark = when (vm.store.themeMode) {
        "dark" -> true
        "light" -> false
        else -> isSystemInDarkTheme()
    }
    XirouterTheme(
        darkTheme = dark,
        accent = vm.store.accent,
        density = vm.store.uiDensity,
        reducedMotion = vm.store.reducedMotion,
        preset = vm.store.appearancePreset,
    ) {
        val toastState = rememberToastHostState()
        CompositionLocalProvider(LocalToastHostState provides toastState) {
            var setupComplete by rememberSaveable { mutableStateOf(vm.configured()) }
            if (!setupComplete) {
                SetupScreen(vm) { setupComplete = true }
            } else {
                var locked by rememberSaveable { mutableStateOf(vm.store.lockEnabled) }
                if (locked && vm.store.lockEnabled) {
                    LockScreen(vm.store.lockPin) { locked = false }
                } else {
                    MainShell(vm, toastState)
                }
            }
            ToastHost(toastState)
        }
    }
}

@Composable
private fun MainShell(vm: XirouterViewModel, toastState: zed.rainxch.rikkaui.components.ui.toast.ToastHostState) {
    val route = vm.nav.current
    val context = LocalContext.current
    androidx.compose.runtime.LaunchedEffect(route) {
        DiagnosticStore(context).add(DiagnosticRecord(System.currentTimeMillis(), DiagnosticKind.Operation, route = route.diagnosticName(), operation = "route_view", lifecycle = "active"))
    }
    val tabs = vm.store.navigationOrder.map(::tabRoute)
    BackHandler(enabled = vm.nav.canPop) { vm.nav.pop() }
    Scaffold(
        modifier = Modifier.statusBarsPadding(),
        topBar = {
            if (route.isTab()) AppTopBar(route, canGoBack = vm.nav.canPop, onBack = vm.nav::pop, onSettings = { vm.nav.push(XRoute.Settings) })
        },
        bottomBar = {
            if (route in tabs) {
                XirouterTabBar(route, tabs, onSelect = { vm.nav.tab(it) }, modifier = Modifier.navigationBarsPadding())
            }
        },
        toastHost = { ToastHost(toastState) },
    ) { padding ->
        Box(Modifier.padding(padding).fillMaxSize(), contentAlignment = androidx.compose.ui.Alignment.TopCenter) {
            Box(Modifier.fillMaxSize().widthIn(max = 720.dp)) {
            when (route) {
                XRoute.Home -> ScreenFrame(vm) { HomeScreen(vm) }
                XRoute.Ledger -> ScreenFrame(vm) { LedgerScreen(vm) }
                XRoute.Data -> ScreenFrame(vm) { DataScreen(vm) }
                XRoute.Live -> ScreenFrame(vm) { LiveScreen(vm) }
                XRoute.Settings -> ScreenFrame(vm) { SettingsScreen(vm) }
                is XRoute.Person -> DetailFrame(vm, "شخص") { PersonDetail(vm, route.personId) }
                is XRoute.YearReport -> DetailFrame(vm, "گزارش سال") { YearReportScreen(vm, route.year) }
                XRoute.Suggestions -> DetailFrame(vm, "پیشنهاد مالکیت") { SuggestionsScreen(vm) }
                XRoute.People -> DetailFrame(vm, "افراد") { PeopleScreen(vm) }
                is XRoute.DeviceWorkspace -> DetailFrame(vm, "دستگاهها") { DeviceWorkspaceScreen(vm, route.personId) }
                is XRoute.OwnershipCorrection -> DetailFrame(vm, "اصلاح مالکیت") { OwnershipCorrectionScreen(vm, route.mac, route.personId) }
                is XRoute.PersonMerge -> DetailFrame(vm, "ادغام اشخاص") { PersonMergeScreen(vm, route.personId) }
            }
            }
        }
    }
}

@Composable
private fun AppTopBar(route: XRoute, canGoBack: Boolean, onBack: () -> Unit, onSettings: () -> Unit) {
    TopAppBar(
        title = { Text(tabLabel(route)) },
        navigationIcon = {
            if (canGoBack) IconButton(Icons.AutoMirrored.Filled.ArrowBack, "بازگشت", onClick = onBack)
        },
        actions = {
            if (route != XRoute.Settings) {
                IconButton(Icons.Filled.Settings, "تنظیمات", onClick = onSettings)
            }
        },
    )
}

private fun XRoute.diagnosticName(): String = when (this) {
    XRoute.Home -> "home"; XRoute.Ledger -> "ledger"; XRoute.Data -> "data_plan"; XRoute.Live -> "live"; XRoute.Settings -> "settings"
    is XRoute.Person -> "person"; is XRoute.YearReport -> "year_report"; XRoute.Suggestions -> "owner_suggestions"; XRoute.People -> "people"
    is XRoute.DeviceWorkspace -> "device_workspace"; is XRoute.OwnershipCorrection -> "ownership_correction"; is XRoute.PersonMerge -> "person_merge"
}

/** Tab screens share the error banner slot. */
@Composable
private fun ScreenFrame(vm: XirouterViewModel, content: @Composable () -> Unit) {
    Column(Modifier.fillMaxSize()) {
        ErrorCard(vm.error.value) { vm.error.value = null }
        content()
    }
}

/** Detail screens get a top bar with back. */
@Composable
private fun DetailFrame(vm: XirouterViewModel, title: String, content: @Composable () -> Unit) {
    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text(title) },
                navigationIcon = {
                    IconButton(
                        icon = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = "بازگشت",
                        onClick = { vm.nav.pop() },
                    )
                },
            )
        },
    ) { padding ->
        Column(Modifier.padding(padding).fillMaxSize()) {
            ErrorCard(vm.error.value) { vm.error.value = null }
            content()
        }
    }
}