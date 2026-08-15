package ir.parsavisions.xirouter

import org.junit.Assert.assertEquals
import org.junit.Test

class NotificationDeliveryTest {
    @Test fun `disabled or permission unavailable delivery advances without retry`() {
        assertEquals(NotificationCycleDecision.Advance, notificationCycleOutcome(NotificationDeliveryOutcome.Disabled))
        assertEquals(NotificationCycleDecision.Advance, notificationCycleOutcome(NotificationDeliveryOutcome.Unavailable))
    }

    @Test fun `genuine notification manager failure retries`() {
        assertEquals(NotificationCycleDecision.Retry, notificationCycleOutcome(NotificationDeliveryOutcome.Error))
    }

    @Test fun `successful delivery advances`() {
        assertEquals(NotificationCycleDecision.Advance, notificationCycleOutcome(NotificationDeliveryOutcome.Delivered))
    }
}
