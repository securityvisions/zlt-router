package ir.parsavisions.xirouter.ui

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue

/** Every place the user can be. Tabs swap the stack; details push onto it. */
sealed interface XRoute {
    data object Home : XRoute
    data object Ledger : XRoute
    data object Data : XRoute
    data object Live : XRoute
    data object Settings : XRoute
    data class Person(val personId: String) : XRoute
    data class YearReport(val year: Int) : XRoute
    data object Suggestions : XRoute
    data object People : XRoute
    data class DeviceWorkspace(val personId: String? = null) : XRoute
    data class OwnershipCorrection(val mac: String? = null, val personId: String? = null) : XRoute
    data class PersonMerge(val personId: String? = null) : XRoute
}

val TAB_ROUTES: List<XRoute> = listOf(XRoute.Home, XRoute.Ledger, XRoute.Data, XRoute.Live, XRoute.Settings)

fun XRoute.isTab(): Boolean = this in TAB_ROUTES

/** Route key used in the landing-tab preference ("home" | "ledger" | ...). */
fun XRoute.tabKey(): String = when (this) {
    XRoute.Home -> "home"
    XRoute.Ledger -> "ledger"
    XRoute.Data -> "data"
    XRoute.Live -> "live"
    XRoute.Settings -> "settings"
    else -> "home"
}

fun tabRoute(key: String): XRoute = when (key) {
    "ledger" -> XRoute.Ledger
    "data" -> XRoute.Data
    "live" -> XRoute.Live
    "settings" -> XRoute.Settings
    else -> XRoute.Home
}

/** A tiny back stack held by the ViewModel so it survives configuration changes. */
class XirouterNav(initial: XRoute = XRoute.Home) {
    var stack by mutableStateOf(listOf(initial))
        private set

    val current: XRoute get() = stack.last()
    val canPop: Boolean get() = stack.size > 1

    fun push(route: XRoute) {
        if (stack.lastOrNull() != route) stack = stack + route
    }

    fun pop() {
        if (stack.size > 1) stack = stack.dropLast(1)
    }

    fun tab(route: XRoute) {
        stack = listOf(route)
    }
}