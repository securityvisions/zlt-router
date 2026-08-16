package ir.parsavisions.xirouter

/** Pure validation seam for user-customizable app chrome and Dashboard preferences. */
object UiPreferences {
    const val DEFAULT_PRESET = "daily"
    val themeModes = setOf("system", "light", "dark")
    val appearancePresets = setOf("calm", "vivid", "focused")
    val densities = setOf("compact", "comfortable")
    val accents = setOf("green", "blue", "violet", "orange", "rose")
    val chartStyles = setOf("line", "area", "bars")
    val chartDetails = setOf("simple", "detailed")
    val primaryDestinations = listOf("home", "ledger", "data")
    val optionalDestinations = setOf("live")
    val dashboardCards = listOf("collection", "ranking", "metrics", "live", "link", "forecast")
    val dashboardSizes = setOf("small", "medium", "full")

    data class DashboardPreset(
        val order: List<String>,
        val hidden: Set<String>,
        val sizes: Map<String, String>,
    )

    val dashboardPresets = mapOf(
        "daily" to DashboardPreset(
            listOf("forecast", "ranking", "collection", "live", "link", "metrics"),
            setOf("metrics"),
            mapOf("forecast" to "full", "ranking" to "full", "collection" to "medium", "live" to "medium", "link" to "medium", "metrics" to "full"),
        ),
        "billing" to DashboardPreset(
            listOf("collection", "ranking", "forecast", "metrics", "link", "live"),
            setOf("live"),
            mapOf("collection" to "full", "ranking" to "full", "forecast" to "medium", "metrics" to "medium", "link" to "medium", "live" to "small"),
        ),
        "troubleshooting" to DashboardPreset(
            listOf("link", "live", "metrics", "forecast", "ranking", "collection"),
            setOf("collection", "ranking"),
            mapOf("link" to "full", "live" to "full", "metrics" to "full", "forecast" to "medium", "ranking" to "medium", "collection" to "small"),
        ),
    )

    fun choice(value: String?, allowed: Set<String>, fallback: String): String = value?.takeIf { it in allowed } ?: fallback

    fun navigation(saved: List<String>, liveInTabs: Boolean): List<String> {
        val allowed = primaryDestinations + optionalDestinations
        val cleaned = saved.distinct().filter { it in allowed }
        val result = (cleaned + primaryDestinations).distinct().filter { liveInTabs || it != "live" }.toMutableList()
        if (liveInTabs && "live" !in result) result += "live"
        return result
    }

    fun dashboardOrder(saved: List<String>): List<String> =
        (saved + dashboardCards).distinct().filter { it in dashboardCards }

    fun dashboardHidden(saved: Set<String>): Set<String> = saved.filter { it in dashboardCards }.toSet()

    fun dashboardSizes(saved: Map<String, String>): Map<String, String> =
        dashboardCards.associateWith { id -> choice(saved[id], dashboardSizes, dashboardPresets.getValue(DEFAULT_PRESET).sizes[id] ?: "medium") }

    fun preset(id: String?): DashboardPreset = dashboardPresets[id] ?: dashboardPresets.getValue(DEFAULT_PRESET)
}
