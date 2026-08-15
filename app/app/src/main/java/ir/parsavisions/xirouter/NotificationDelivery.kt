package ir.parsavisions.xirouter

import kotlinx.serialization.Serializable

/** Delivery is intentionally richer than Boolean: unavailable delivery is not a transient failure. */
enum class NotificationDeliveryOutcome { Delivered, Disabled, Unavailable, Error }
enum class NotificationCycleDecision { Advance, Retry }

fun notificationCycleOutcome(outcome: NotificationDeliveryOutcome): NotificationCycleDecision =
    if (outcome == NotificationDeliveryOutcome.Error) NotificationCycleDecision.Retry else NotificationCycleDecision.Advance
