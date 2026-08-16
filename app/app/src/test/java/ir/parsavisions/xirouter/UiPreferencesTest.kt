package ir.parsavisions.xirouter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class UiPreferencesTest {
    @Test fun `invalid choices fall back safely`() {
        assertEquals("system", UiPreferences.choice("neon", UiPreferences.themeModes, "system"))
        assertEquals("dark", UiPreferences.choice("dark", UiPreferences.themeModes, "system"))
    }

    @Test fun `navigation keeps required destinations and validates live placement`() {
        assertEquals(listOf("data", "home", "ledger"), UiPreferences.navigation(listOf("data", "data", "bogus"), false))
        val withLive = UiPreferences.navigation(listOf("ledger", "live"), true)
        assertEquals(listOf("ledger", "live", "home", "data"), withLive)
        assertTrue(withLive.containsAll(UiPreferences.primaryDestinations))
    }

    @Test fun `dashboard values reject unknown ids and invalid sizes`() {
        assertEquals(listOf("metrics", "collection", "ranking", "live", "link", "forecast"), UiPreferences.dashboardOrder(listOf("metrics", "bad")))
        assertEquals(setOf("live"), UiPreferences.dashboardHidden(setOf("live", "bad")))
        val sizes = UiPreferences.dashboardSizes(mapOf("metrics" to "giant", "live" to "small"))
        assertEquals("full", sizes["metrics"])
        assertEquals("small", sizes["live"])
    }

    @Test fun `presets are constrained and leave useful content visible`() {
        UiPreferences.dashboardPresets.values.forEach { preset ->
            assertEquals(UiPreferences.dashboardCards.toSet(), preset.order.toSet())
            assertTrue(preset.hidden.all { it in UiPreferences.dashboardCards })
            assertTrue(preset.sizes.values.all { it in UiPreferences.dashboardSizes })
            assertFalse(preset.hidden.containsAll(UiPreferences.dashboardCards))
        }
    }
}
