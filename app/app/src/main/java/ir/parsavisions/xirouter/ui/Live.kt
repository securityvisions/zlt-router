package ir.parsavisions.xirouter.ui

import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.lifecycle.Lifecycle
import androidx.lifecycle.LifecycleEventObserver
import androidx.lifecycle.compose.LocalLifecycleOwner
import androidx.lifecycle.compose.collectAsStateWithLifecycle
import ir.parsavisions.xirouter.Format
import ir.parsavisions.xirouter.LiveBandwidthSample
import ir.parsavisions.xirouter.LiveBandwidthState
import ir.parsavisions.xirouter.LiveBandwidthStatus
import ir.parsavisions.xirouter.LiveBandwidthTransitions
import ir.parsavisions.xirouter.LiveCounters
import ir.parsavisions.xirouter.LiveDeviceCounters
import ir.parsavisions.xirouter.LiveRate
import ir.parsavisions.xirouter.XirouterViewModel
import ir.parsavisions.xirouter.cancellationAwareResult
import kotlinx.coroutines.delay
import zed.rainxch.rikkaui.components.ui.button.Button
import zed.rainxch.rikkaui.components.ui.icon.Icon
import zed.rainxch.rikkaui.components.ui.text.Text
import zed.rainxch.rikkaui.components.ui.text.TextVariant
import zed.rainxch.rikkaui.foundation.RikkaTheme

/** Live bandwidth polling only while this screen's lifecycle is started. */
@Composable
fun LiveScreen(vm: XirouterViewModel) {
    val transitions = remember { LiveBandwidthTransitions() }
    var live by remember { mutableStateOf(LiveBandwidthState()) }
    var retryKey by remember { mutableIntStateOf(0) }
    val devices by vm.devices.collectAsStateWithLifecycle()
    val names = devices.associate { it.mac to it.alias.ifBlank { it.lastSeenName } }
    val lifecycle = LocalLifecycleOwner.current.lifecycle
    var started by remember { mutableStateOf(lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)) }

    DisposableEffect(lifecycle) {
        val observer = LifecycleEventObserver { _, _ ->
            val nowStarted = lifecycle.currentState.isAtLeast(Lifecycle.State.STARTED)
            if (started && !nowStarted) transitions.stopped()
            started = nowStarted
        }
        lifecycle.addObserver(observer)
        onDispose {
            transitions.stopped()
            lifecycle.removeObserver(observer)
        }
    }
    LaunchedEffect(started, retryKey) {
        if (!started) return@LaunchedEffect
        var failures = 0
        while (true) {
            val response = cancellationAwareResult { vm.fetchLive() }.getOrNull()
            if (response == null) {
                failures++
                live = transitions.failed()
            } else {
                failures = 0
                live = transitions.transition(
                    LiveBandwidthSample(
                        timestampMillis = response.ts,
                        wan = LiveCounters(response.wan.rx_bytes, response.wan.tx_bytes),
                        devices = response.devices.map { LiveDeviceCounters(it.mac, it.rx_bytes, it.tx_bytes) },
                    ),
                    receivedAtMillis = System.currentTimeMillis(),
                )
            }
            delay(if (failures > 0) 3_000 else 1_500)
        }
    }

    LazyColumn(Modifier.fillMaxWidth()) {
        item { LiveStateBanner(live.status, live.lastSuccessMillis) { retryKey++ } }
        item { SectionTitle("اینترنت") }
        item {
            Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg)) {
                DetailRow("دریافت", humanRate(live.wan.rxBytesPerSec), bold = true)
                DetailRow("ارسال", humanRate(live.wan.txBytesPerSec), bold = true)
            }
        }
        item { SectionTitle("به تفکیک دستگاه") }
        if (live.deviceRates.isEmpty()) item {
            Column(Modifier.fillMaxWidth().padding(vertical = RikkaTheme.spacing.xl), horizontalAlignment = Alignment.CenterHorizontally) {
                Text(if (live.status == LiveBandwidthStatus.Initializing) "در حال اندازهگیری…" else "دادهٔ زندهای در دسترس نیست", variant = TextVariant.Muted)
            }
        } else items(live.deviceRates.toList().sortedByDescending { it.second.rxBytesPerSec }, key = { it.first }) { (mac, rate) ->
            Panel(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = 4.dp)) {
                BoxWithConstraints(Modifier.fillMaxWidth()) {
                    val compact = maxWidth < 320.dp || LocalDensity.current.fontScale > 1.2f
                    if (compact) Column {
                        DeviceRate(names[mac], mac, rate); Spacer(Modifier.height(6.dp)); Sparkline(live.histories[mac].orEmpty(), Modifier.fillMaxWidth().height(26.dp))
                    } else Row(verticalAlignment = Alignment.CenterVertically) {
                        Column(Modifier.weight(1f)) { DeviceRate(names[mac], mac, rate) }
                        Sparkline(live.histories[mac].orEmpty(), Modifier.width(72.dp).height(26.dp))
                    }
                }
            }
        }
        item { Spacer(Modifier.height(24.dp)) }
    }
}

@Composable private fun LiveStateBanner(state: LiveBandwidthStatus, lastSuccess: Long, retry: () -> Unit) {
    val label = when (state) {
        LiveBandwidthStatus.Initializing -> "در حال آمادهسازی اندازهگیری"
        LiveBandwidthStatus.Live -> "زنده"
        LiveBandwidthStatus.Stale -> "اتصال قطع است؛ آخرین اندازهگیری نمایش داده میشود"
        LiveBandwidthStatus.Offline -> "روتر در دسترس نیست"
    }
    BoxWithConstraints(Modifier.fillMaxWidth().padding(horizontal = RikkaTheme.spacing.lg, vertical = 8.dp)) {
        val compact = maxWidth < 360.dp || LocalDensity.current.fontScale > 1.2f
        val status = @Composable {
            StatusPill(label, when (state) { LiveBandwidthStatus.Live -> StatusColors.up; LiveBandwidthStatus.Initializing -> StatusColors.warning; else -> StatusColors.down })
        }
        val details = @Composable {
            Row(verticalAlignment = Alignment.CenterVertically) {
                if (lastSuccess > 0) Text("آخرین موفق: ${liveTime(lastSuccess)}", variant = TextVariant.Small, modifier = Modifier.weight(1f, fill = false).padding(end = 8.dp))
                if (state == LiveBandwidthStatus.Stale || state == LiveBandwidthStatus.Offline) Button(onClick = retry) { Icon(Icons.Filled.Refresh, "تلاش دوباره") }
            }
        }
        if (compact) Column(verticalArrangement = Arrangement.spacedBy(8.dp)) { status(); details() }
        else Row(verticalAlignment = Alignment.CenterVertically) { Box(Modifier.weight(1f)) { status() }; details() }
    }
}

@Composable private fun DeviceRate(name: String?, mac: String, rate: LiveRate) {
    Text(name?.ifBlank { null } ?: "\u2066${mac.take(17)}\u2069", variant = TextVariant.P, style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold))
    Text("دریافت ${humanRate(rate.rxBytesPerSec)} · ارسال ${humanRate(rate.txBytesPerSec)}", variant = TextVariant.Muted)
}

private fun humanRate(bps: Long): String = when {
    bps >= 1_000_000 -> "${Format.faNum("%.1f".format(bps / 1_000_000.0))} MB/s"
    bps >= 1_000 -> "${Format.faNum("%.0f".format(bps / 1_000.0))} KB/s"
    else -> "${Format.faNum("$bps")} B/s"
}
private fun liveTime(ts: Long): String = java.time.format.DateTimeFormatter.ofPattern("HH:mm:ss").withZone(java.time.ZoneId.of("Asia/Tehran")).format(java.time.Instant.ofEpochMilli(ts))
