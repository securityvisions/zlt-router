package ir.parsavisions.xirouter

import android.content.Context
import androidx.work.CoroutineWorker
import androidx.work.WorkerParameters
import kotlinx.serialization.Serializable
import java.text.SimpleDateFormat
import java.util.Locale

/** One poll of router state — the input to the notification diff. */
@Serializable
data class RouterSnapshot(
    val balanceTier: Int,
    val proxyUp: Boolean,
    val deviceMacs: Set<String>,
    val diskPct: Int,
    val uptimeSecs: Long,
    val drainRateGbh: Double,
    val remainingGb: Double,
)

/** The app's alert vocabulary — one event per notifiable condition. */
enum class AlertEvent {
    BalanceNotice, BalanceWarn, BalanceUrgent, BalanceExhausted,
    ProxyUp, ProxyDown, NewDevice, DiskHigh, Reboot, HighDrain, BillReady;

    companion object {
        fun balanceTier(tier: Int): AlertEvent = when (tier) {
            1 -> BalanceNotice; 2 -> BalanceWarn; 3 -> BalanceUrgent; 4 -> BalanceExhausted
            else -> throw IllegalArgumentException("no alert event for tier $tier")
        }
    }
}

/**
 * The app's "what is notifiable" rules (mirrors the bot's cron alerts).
 * First poll baselines silently; a later poll diffs against it and emits events.
 */
object NotificationEvents {
    fun events(prev: RouterSnapshot?, curr: RouterSnapshot): List<AlertEvent> {
        if (prev == null) return emptyList()
        val out = mutableListOf<AlertEvent>()
        if (curr.balanceTier > prev.balanceTier && curr.balanceTier >= 2) {
            out.add(AlertEvent.balanceTier(curr.balanceTier))
        }
        if (curr.proxyUp != prev.proxyUp) {
            out.add(if (curr.proxyUp) AlertEvent.ProxyUp else AlertEvent.ProxyDown)
        }
        if ((curr.deviceMacs - prev.deviceMacs).isNotEmpty()) out.add(AlertEvent.NewDevice)
        if (curr.diskPct > 85 && prev.diskPct <= 85) out.add(AlertEvent.DiskHigh)
        if (curr.uptimeSecs < prev.uptimeSecs - 60) out.add(AlertEvent.Reboot)
        if (curr.drainRateGbh >= 5.0 && curr.remainingGb < 30.0 && prev.drainRateGbh < 5.0) {
            out.add(AlertEvent.HighDrain)
        }
        return out
    }

    /** A drain rate in GB/hour from two balance-history points (GB each, dated ISO). */
    fun drainRateGbh(points: List<BalancePoint>): Double {
        if (points.size < 2) return 0.0
        val newest = points.sortedBy { it.date }.takeLast(2)
        val a = newest[0]; val b = newest[1]
        val days = try {
            val fmt = SimpleDateFormat("yyyy-MM-dd", Locale.US)
            (fmt.parse(b.date)!!.time - fmt.parse(a.date)!!.time) / 86_400_000.0
        } catch (e: Exception) { 0.0 }
        if (days <= 0) return 0.0
        val drop = (a.gb - b.gb).coerceAtLeast(0.0)   // skip package-add days
        return drop / days / 24.0
    }
}

/** The monthly-bill notification fires once, on the 1st, until the next month. */
object BillReady {
    fun due(today: String, lastNotified: String?): Boolean =
        today.endsWith("-01") && lastNotified != today
}

/** "3 days, 4:12" / "4:12" / "1 min" -> seconds. Rough is enough to detect a reboot. */
object Uptime {
    fun parse(uptime: String?): Long {
        if (uptime == null) return Long.MAX_VALUE
        return try {
            val days = uptime.split("day").getOrNull(0)?.trim()?.toLongOrNull() ?: 0L
            val rest = uptime.split(",").lastOrNull()?.trim().orEmpty()
            val parts = rest.split(":").map { it.trim().toLongOrNull() ?: 0L }
            val hours = parts.getOrElse(0) { 0L }
            val mins = parts.getOrElse(1) { 0L }
            days * 86_400L + hours * 3_600L + mins * 60L
        } catch (e: Exception) { Long.MAX_VALUE }
    }
}

/** Builds the diff snapshot from API responses — shared by the worker and the UI. */
object Snapshots {
    fun from(status: StatusDto?, balance: BalanceResponse?, clients: ClientsResponse?): RouterSnapshot {
        val aggregate = balance?.aggregate()
        val tier = aggregate?.let {
            val pct = if ((it.quota_gb ?: 0.0) > 0) (it.remain_gb ?: 0.0) / it.quota_gb!! * 100 else 0.0
            BalanceTier.decide(it.remain_gb ?: 0.0, pct, balance.main?.days ?: 9999, projectedDays(balance))
        } ?: 0
        return RouterSnapshot(
            balanceTier = tier,
            proxyUp = status?.proxy?.state == "up",
            deviceMacs = clients?.clients?.map { it.mac }?.toSet() ?: emptySet(),
            diskPct = status?.disk?.pct ?: 0,
            uptimeSecs = Uptime.parse(status?.uptime),
            drainRateGbh = NotificationEvents.drainRateGbh(balance?.series ?: emptyList()),
            remainingGb = aggregate?.remain_gb ?: balance?.total_gb ?: 0.0,
        )
    }

    private fun projectedDays(b: BalanceResponse?): Double {
        val rateGbh = NotificationEvents.drainRateGbh(b?.series ?: emptyList())
        if (rateGbh <= 0.01) return 999.0
        return (b?.aggregate()?.remain_gb ?: b?.total_gb ?: 0.0) / (rateGbh * 24)
    }
}

/**
 * Background poller: runs every 15 minutes while the phone is on the home network,
 * diffs the last known snapshot and posts local notifications for events.
 */
class NotifyWorker(context: Context, params: WorkerParameters) : CoroutineWorker(context, params) {
    override suspend fun doWork(): Result {
        if (!Store(applicationContext).configured()) return Result.success()
        return when (SnapshotPollingCycle(AndroidSnapshotCycleRuntime(applicationContext)).run(SnapshotCycleRequest.Worker).outcome) {
            SnapshotCycleOutcome.Success -> Result.success()
            SnapshotCycleOutcome.Retry -> Result.retry()
        }
    }
}
