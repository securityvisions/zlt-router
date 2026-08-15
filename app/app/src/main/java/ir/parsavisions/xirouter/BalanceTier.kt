package ir.parsavisions.xirouter

/**
 * Balance tier — mirrors the router's decide_tier so the app and bot agree.
 * 0 none, 1 notice, 2 warn, 3 urgent, 4 exhausted.
 */
object BalanceTier {
    fun decide(remainingGb: Double, pct: Double, daysToExpiry: Int, projectedDays: Double): Int = when {
        remainingGb < 0.05 -> 4
        remainingGb < 3.0 || daysToExpiry < 3 || projectedDays < 7 -> 3
        remainingGb < 10.0 || daysToExpiry < 7 || projectedDays < 14 -> 2
        pct < 25.0 || projectedDays < 30 -> 1
        else -> 0
    }
}
