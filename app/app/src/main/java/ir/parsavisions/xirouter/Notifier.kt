package ir.parsavisions.xirouter

import android.app.NotificationChannel
import android.app.NotificationManager
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import androidx.core.app.NotificationCompat
import androidx.core.app.NotificationManagerCompat

/** Posts local notifications for alert events, respecting the per-event toggles. */
object Notifier {
    private const val CHANNEL_ID = "xirouter_alerts"

    fun ensureChannel(context: Context) {
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.O) {
            val manager = context.getSystemService(Context.NOTIFICATION_SERVICE) as NotificationManager
            val channel = NotificationChannel(CHANNEL_ID, "Xirouter alerts", NotificationManager.IMPORTANCE_DEFAULT)
            manager.createNotificationChannel(channel)
        }
    }

    fun postPackages(context: Context, alerts: List<PackageAlert>, packages: Map<String, PackageEntity>): NotificationDeliveryOutcome {
        if (alerts.isEmpty()) return NotificationDeliveryOutcome.Disabled
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return NotificationDeliveryOutcome.Unavailable
        ensureChannel(context)
        val manager = NotificationManagerCompat.from(context)
        var succeeded = true
        alerts.forEach { alert ->
            val packageName = packages[alert.packageId]?.let { it.alias.ifBlank { it.routerName.ifBlank { it.provider.ifBlank { it.id } } } } ?: alert.packageId
            val (title, body) = when (alert.kind) {
                PackageAlertKind.LOW -> "موجودی بسته کم است" to "بستهٔ «$packageName» از آستانهٔ تعیینشده عبور کرد."
                PackageAlertKind.DEPLETED -> "بسته تمام شد" to "بستهٔ «$packageName» تمام شده است."
                PackageAlertKind.NEW -> "بستهٔ جدید" to "بستهٔ «$packageName» به Data plan اضافه شد."
                PackageAlertKind.DISAPPEARED -> "بسته ناپدید شد" to "بستهٔ «$packageName» پس از سه دریافت موفق دیگر گزارش نشد."
                PackageAlertKind.EXPIRY -> "انقضای نزدیک بسته" to "بستهٔ «$packageName» تا سه روز آینده منقضی میشود."
            }
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info).setContentTitle(title).setContentText(body).setAutoCancel(true).build()
            if (runCatching { manager.notify(20_000 + (alert.packageId + alert.kind).hashCode(), notification) }.isFailure) succeeded = false
        }
        return if (succeeded) NotificationDeliveryOutcome.Delivered else NotificationDeliveryOutcome.Error
    }

    /** Disabled or unavailable delivery advances state; only a genuine manager error retries. */
    fun post(context: Context, events: List<AlertEvent>, store: Store): NotificationDeliveryOutcome {
        val enabled = events.filter { allowed(it, store) }
        if (enabled.isEmpty()) return NotificationDeliveryOutcome.Disabled
        if (Build.VERSION.SDK_INT >= 33 &&
            context.checkSelfPermission(android.Manifest.permission.POST_NOTIFICATIONS) != PackageManager.PERMISSION_GRANTED
        ) return NotificationDeliveryOutcome.Unavailable
        ensureChannel(context)

        var succeeded = true
        val manager = NotificationManagerCompat.from(context)
        enabled.forEach { event ->
            val (title, body) = message(event)
            val notification = NotificationCompat.Builder(context, CHANNEL_ID)
                .setSmallIcon(android.R.drawable.ic_dialog_info)
                .setContentTitle(title)
                .setContentText(body)
                .setAutoCancel(true)
                .build()
            // IDs are event-stable so retrying a partially delivered batch replaces prior successes.
            if (runCatching { manager.notify(notificationId(event), notification) }.isFailure) succeeded = false
        }
        return if (succeeded) NotificationDeliveryOutcome.Delivered else NotificationDeliveryOutcome.Error
    }

    private fun notificationId(event: AlertEvent): Int = 1000 + event.name.hashCode()

    private fun allowed(event: AlertEvent, store: Store): Boolean = when (event) {
        AlertEvent.BalanceNotice, AlertEvent.BalanceWarn,
        AlertEvent.BalanceUrgent, AlertEvent.BalanceExhausted -> store.notifBalance
        AlertEvent.ProxyUp, AlertEvent.ProxyDown -> store.notifProxy
        AlertEvent.NewDevice -> store.notifDevice
        AlertEvent.DiskHigh -> store.notifDisk
        AlertEvent.Reboot -> store.notifReboot
        AlertEvent.HighDrain -> store.notifDrain
        AlertEvent.BillReady -> store.notifBill
    }

    private fun message(event: AlertEvent): Pair<String, String> = when (event) {
        AlertEvent.ProxyDown -> "پروکسی قطع شد" to "مسیر اینترنت افت کرد — روتر به اتصال مستقیم برگشت."
        AlertEvent.ProxyUp -> "پروکسی وصل شد" to "مسیر پروکسی دوباره برقرار شد."
        AlertEvent.NewDevice -> "دستگاه جدید" to "یک دستگاه جدید به شبکه وصل شد."
        AlertEvent.DiskHigh -> "حافظه تقریباً پر است" to "مصرف حافظهٔ روتر از ۸۵٪ گذشت."
        AlertEvent.Reboot -> "روتر راه‌اندازی مجدد شد" to "روتر ری‌استارت شد؛ اعلان‌ها ادامه دارد."
        AlertEvent.HighDrain -> "مصرف بالا" to "دانلود سنگین در جریان است و موجودی زیر ۳۰ گیگابایت است."
        AlertEvent.BillReady -> "قبض ماهانه آماده است" to "قبض ماه قبل در دفترحساب ثبت شد."
        AlertEvent.BalanceNotice -> "نزدیک به هشدار موجودی" to "کمتر از ۲۵٪ بسته مانده یا با این روند کمتر از ۳۰ روز دوام دارد."
        AlertEvent.BalanceWarn -> "هشدار موجودی" to "موجودی زیر ۱۰ گیگابایت است یا بسته نزدیک انقضاست."
        AlertEvent.BalanceUrgent -> "موجودی کم" to "زیر ۳ گیگابایت مانده یا کمتر از یک هفته — زودتر تمدید کنید."
        AlertEvent.BalanceExhausted -> "بسته تمام شد" to "بستهٔ اینترنت تمام شد — تمدید کنید."
    }
}
