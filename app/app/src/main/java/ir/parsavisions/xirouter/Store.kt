package ir.parsavisions.xirouter

import android.content.Context

/** App settings — persisted locally, nothing leaves the phone. */
class Store(context: Context) {
    companion object {
        val DASHBOARD_CARDS = UiPreferences.dashboardCards
    }

    private val prefs = context.getSharedPreferences("xirouter", Context.MODE_PRIVATE)

    var baseUrl: String
        get() = prefs.getString("base_url", "http://192.168.1.1/cgi-bin/routerapi.sh")!!
        set(v) = prefs.edit().putString("base_url", v).apply()

    var token: String
        get() = prefs.getString("token", "")!!
        set(v) = prefs.edit().putString("token", v).apply()

    /** The default per-GB price applied to a person's monthly usage (Toman). */
    var defaultRate: Long
        get() = prefs.getLong("default_rate", 7700)
        set(v) = prefs.edit().putLong("default_rate", v).apply()

    /** Legacy completion marker retained for existing installs. */
    var importedRouterHistory: Boolean
        get() = prefs.getBoolean("imported_router_history", false)
        set(v) = prefs.edit().putBoolean("imported_router_history", v).apply()

    /** Successfully imported Gregorian source months; makes a partial scan resumable. */
    var importedRouterSourceMonths: Set<String>
        get() = prefs.getStringSet("imported_router_source_months", emptySet())?.toSet().orEmpty()
        set(v) = prefs.edit().putStringSet("imported_router_source_months", v).apply()

    /** Theme: system, dark, or light. Invalid persisted values self-heal on read. */
    var themeMode: String
        get() = UiPreferences.choice(prefs.getString("theme_mode", null), UiPreferences.themeModes, "system")
        set(v) = prefs.edit().putString("theme_mode", UiPreferences.choice(v, UiPreferences.themeModes, "system")).apply()

    var appearancePreset: String
        get() = UiPreferences.choice(prefs.getString("appearance_preset", null), UiPreferences.appearancePresets, "calm")
        set(v) = prefs.edit().putString("appearance_preset", UiPreferences.choice(v, UiPreferences.appearancePresets, "calm")).apply()

    var uiDensity: String
        get() = UiPreferences.choice(prefs.getString("ui_density", null), UiPreferences.densities, "comfortable")
        set(v) = prefs.edit().putString("ui_density", UiPreferences.choice(v, UiPreferences.densities, "comfortable")).apply()

    var accent: String
        get() = UiPreferences.choice(prefs.getString("accent", null), UiPreferences.accents, "green")
        set(v) = prefs.edit().putString("accent", UiPreferences.choice(v, UiPreferences.accents, "green")).apply()

    var reducedMotion: Boolean
        get() = prefs.getBoolean("reduced_motion", false)
        set(v) = prefs.edit().putBoolean("reduced_motion", v).apply()

    var chartStyle: String
        get() = UiPreferences.choice(prefs.getString("chart_style", null), UiPreferences.chartStyles, "area")
        set(v) = prefs.edit().putString("chart_style", UiPreferences.choice(v, UiPreferences.chartStyles, "area")).apply()

    var chartDetail: String
        get() = UiPreferences.choice(prefs.getString("chart_detail", null), UiPreferences.chartDetails, "detailed")
        set(v) = prefs.edit().putString("chart_detail", UiPreferences.choice(v, UiPreferences.chartDetails, "detailed")).apply()

    /** Landing tab route key for the powered-on app. */
    var landingTab: String
        get() = prefs.getString("landing_tab", "home")!!.takeIf { it in UiPreferences.primaryDestinations + UiPreferences.optionalDestinations } ?: "home"
        set(v) = prefs.edit().putString("landing_tab", v.takeIf { it in UiPreferences.primaryDestinations + UiPreferences.optionalDestinations } ?: "home").apply()

    var liveInTabs: Boolean
        get() = prefs.getBoolean("live_in_tabs", true)
        set(v) = prefs.edit().putBoolean("live_in_tabs", v).apply()

    var navigationOrder: List<String>
        get() = UiPreferences.navigation(prefs.getString("navigation_order", null)?.split(',').orEmpty(), liveInTabs)
        set(v) = prefs.edit().putString("navigation_order", UiPreferences.navigation(v, liveInTabs).joinToString(",")).apply()

    /** Serialized RouterSnapshot of the last successful poll (the notification baseline). */
    var lastSnapshot: String?
        get() = prefs.getString("last_snapshot", null)
        set(v) = prefs.edit().putString("last_snapshot", v).apply()

    /** The "YYYY-MM-DD" the monthly-bill notification last fired (once per month). */
    var lastBillNotifDate: String?
        get() = prefs.getString("last_bill_notif", null)
        set(v) = prefs.edit().putString("last_bill_notif", v).apply()

    /** Advance Snapshot and bill-ready baselines together, after Notification delivery. */
    fun advanceNotificationBaseline(snapshot: String, billDate: String?): Boolean =
        prefs.edit().putString("last_snapshot", snapshot).putString("last_bill_notif", billDate).commit()

    var notifBalance: Boolean
        get() = prefs.getBoolean("notif_balance", true)
        set(v) = prefs.edit().putBoolean("notif_balance", v).apply()
    var notifDevice: Boolean
        get() = prefs.getBoolean("notif_device", true)
        set(v) = prefs.edit().putBoolean("notif_device", v).apply()
    var notifProxy: Boolean
        get() = prefs.getBoolean("notif_proxy", true)
        set(v) = prefs.edit().putBoolean("notif_proxy", v).apply()
    var notifDisk: Boolean
        get() = prefs.getBoolean("notif_disk", true)
        set(v) = prefs.edit().putBoolean("notif_disk", v).apply()
    var notifReboot: Boolean
        get() = prefs.getBoolean("notif_reboot", true)
        set(v) = prefs.edit().putBoolean("notif_reboot", v).apply()
    var notifBill: Boolean
        get() = prefs.getBoolean("notif_bill", true)
        set(v) = prefs.edit().putBoolean("notif_bill", v).apply()
    var notifDrain: Boolean
        get() = prefs.getBoolean("notif_drain", true)
        set(v) = prefs.edit().putBoolean("notif_drain", v).apply()
    var packageAlerts: Boolean
        get() = prefs.getBoolean("package_alerts", true)
        set(v) = prefs.edit().putBoolean("package_alerts", v).apply()
    var packageBaselineEstablished: Boolean
        get() = prefs.getBoolean("package_baseline_established", false)
        set(v) = prefs.edit().putBoolean("package_baseline_established", v).apply()
    var packageAlertThresholdPct: Int
        get() = prefs.getInt("package_alert_threshold", 20)
        set(v) = prefs.edit().putInt("package_alert_threshold", v.coerceIn(1, 100)).apply()
    var packageDisplayMode: String
        get() = PackageDisplayMode.parse(prefs.getString("package_display_mode", null)).value
        set(v) = prefs.edit().putString("package_display_mode", PackageDisplayMode.parse(v).value).apply()

    var notificationPermissionRequested: Boolean
        get() = prefs.getBoolean("notification_permission_requested", false)
        set(v) = prefs.edit().putBoolean("notification_permission_requested", v).apply()

    var lockEnabled: Boolean
        get() = prefs.getBoolean("lock_enabled", false) && lockPin.isNotBlank()
        set(v) {
            // Enabling is only valid after a PIN has been durably saved.
            prefs.edit().putBoolean("lock_enabled", v && lockPin.isNotBlank()).apply()
        }
    var lockPin: String
        get() = prefs.getString("lock_pin", "")!!
        set(v) = prefs.edit().putString("lock_pin", v).apply()

    /** Ordered dashboard card IDs. Unknown IDs are ignored and new defaults are appended. */
    var dashboardOrder: List<String>
        get() = UiPreferences.dashboardOrder(prefs.getString("dashboard_order", null)?.split(',')?.filter(String::isNotBlank).orEmpty())
        set(v) = prefs.edit().putString("dashboard_order", UiPreferences.dashboardOrder(v).joinToString(",")).apply()

    var dashboardHidden: Set<String>
        get() = UiPreferences.dashboardHidden(prefs.getStringSet("dashboard_hidden", emptySet()).orEmpty())
        set(v) = prefs.edit().putStringSet("dashboard_hidden", UiPreferences.dashboardHidden(v)).apply()

    var dashboardSizes: Map<String, String>
        get() = UiPreferences.dashboardSizes(prefs.getString("dashboard_sizes", null)?.split(',')?.mapNotNull {
            val pair = it.split(':', limit = 2)
            pair.takeIf { values -> values.size == 2 }?.let { values -> values[0] to values[1] }
        }?.toMap().orEmpty())
        set(v) = prefs.edit().putString("dashboard_sizes", UiPreferences.dashboardSizes(v).entries.joinToString(",") { "${it.key}:${it.value}" }).apply()

    fun applyDashboardPreset(id: String) {
        val preset = UiPreferences.preset(id)
        prefs.edit()
            .putString("dashboard_order", preset.order.joinToString(","))
            .putStringSet("dashboard_hidden", preset.hidden)
            .putString("dashboard_sizes", preset.sizes.entries.joinToString(",") { "${it.key}:${it.value}" })
            .apply()
    }

    /** Whether compact Ledger cards expose usage, owed, and note details. */
    var ledgerDetailColumns: Boolean
        get() = prefs.getBoolean("ledger_detail_columns", true)
        set(v) = prefs.edit().putBoolean("ledger_detail_columns", v).apply()

    /** Save PIN and enabled state in one preference transaction. */
    fun configureAppLock(pin: String): Boolean {
        val clean = pin.filter(Char::isDigit).take(8)
        if (clean.isBlank()) return false
        return prefs.edit().putString("lock_pin", clean).putBoolean("lock_enabled", true).commit()
    }

    fun notificationsEnabled(): Boolean =
        notifBalance || notifDevice || notifProxy || notifDisk || notifReboot || notifBill || notifDrain

    fun appLockConfigured(): Boolean = lockEnabled && lockPin.isNotBlank()

    fun configured(): Boolean = token.isNotBlank() && baseUrl.isNotBlank()
}
