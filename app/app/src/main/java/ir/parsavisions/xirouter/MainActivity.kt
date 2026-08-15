package ir.parsavisions.xirouter

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import android.app.AlertDialog
import androidx.activity.viewModels
import androidx.work.Constraints
import androidx.work.ExistingPeriodicWorkPolicy
import androidx.work.NetworkType
import androidx.work.PeriodicWorkRequestBuilder
import androidx.work.WorkManager
import ir.parsavisions.xirouter.ui.XirouterApp
import ir.parsavisions.xirouter.ui.XirouterTheme
import java.util.concurrent.TimeUnit

class MainActivity : ComponentActivity() {
    private val notificationPermission = registerForActivityResult(ActivityResultContracts.RequestPermission()) { granted ->
        Store(applicationContext).notificationPermissionRequested = true
        DiagnosticStore(applicationContext).add(DiagnosticRecord(System.currentTimeMillis(), DiagnosticKind.Operation, operation = if (granted) "notification_permission_granted" else "notification_permission_denied", lifecycle = "active"))
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        DiagnosticStore(applicationContext).add(DiagnosticRecord(System.currentTimeMillis(), DiagnosticKind.Operation, route = "startup", operation = "session_start", lifecycle = "created"))
        Notifier.ensureChannel(this)
        requestNotificationPermissionWithExplanation()
        scheduleBackgroundPoll()
        val vm: XirouterViewModel by viewModels()
        setContent {
            XirouterTheme {
                XirouterApp(vm)
            }
        }
    }

    private fun requestNotificationPermissionWithExplanation() {
        val store = Store(applicationContext)
        if (Build.VERSION.SDK_INT < 33 || store.notificationPermissionRequested || checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) return
        AlertDialog.Builder(this)
            .setTitle("اجازهٔ اعلانها")
            .setMessage("Xirouter برای هشدار موجودی، قطعی پروکسی و دستگاه جدید به اجازهٔ اعلان نیاز دارد. بدون این اجازه پایش و ثبت داده ادامه پیدا میکند، اما هشداری نمایش داده نمیشود.")
            .setNegativeButton("فعلاً نه") { _, _ -> store.notificationPermissionRequested = true }
            .setPositiveButton("ادامه") { _, _ -> store.notificationPermissionRequested = true; notificationPermission.launch(Manifest.permission.POST_NOTIFICATIONS) }
            .show()
    }

    /** Background notification poller + ledger recorder (15 min) on the home network. */
    private fun scheduleBackgroundPoll() {
        val request = PeriodicWorkRequestBuilder<NotifyWorker>(15, TimeUnit.MINUTES)
            .setConstraints(Constraints.Builder().setRequiredNetworkType(NetworkType.CONNECTED).build())
            .build()
        WorkManager.getInstance(this)
            .enqueueUniquePeriodicWork("xirouter_poll", ExistingPeriodicWorkPolicy.KEEP, request)
    }
}