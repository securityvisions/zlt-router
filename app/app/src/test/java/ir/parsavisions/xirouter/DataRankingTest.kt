package ir.parsavisions.xirouter.ui

import ir.parsavisions.xirouter.CostRow
import ir.parsavisions.xirouter.DeviceSettingsEntity
import ir.parsavisions.xirouter.UsageRow
import org.junit.Assert.assertEquals
import org.junit.Test

class DataRankingTest {
    @Test
    fun `rankings join duplicate API names by MAC and prefer stable aliases`() {
        val usage = listOf(
            UsageRow(name = "Phone", mac = "AA:00:00:00:00:01", gb = 3.0),
            UsageRow(name = "Phone", mac = "AA:00:00:00:00:02", gb = 1.0),
        )
        val costs = listOf(
            CostRow(name = "Phone", mac = "AA:00:00:00:00:01", gb = 3.0, toman = 23_000, share = 75.0),
            CostRow(name = "Phone", mac = "AA:00:00:00:00:02", gb = 1.0, toman = 8_000, share = 25.0),
        )
        val devices = listOf(
            DeviceSettingsEntity(mac = "aa:00:00:00:00:01", alias = "گوشی اول"),
            DeviceSettingsEntity(mac = "aa:00:00:00:00:02", alias = "گوشی دوم"),
        )

        val rows = deviceRankings(usage, costs, devices)

        assertEquals(2, rows.size)
        assertEquals(setOf("گوشی اول", "گوشی دوم"), rows.map { it.label }.toSet())
        assertEquals(setOf(23_000L, 8_000L), rows.map { it.toman }.toSet())
    }

    @Test
    fun `legacy cost rows only join by a unique API name`() {
        val usage = listOf(UsageRow(name = "Laptop", mac = "bb:00:00:00:00:01", gb = 2.0))
        val costs = listOf(CostRow(name = "Laptop", toman = 15_000, share = 100.0))

        val row = deviceRankings(usage, costs, emptyList()).single()

        assertEquals("bb:00:00:00:00:01", row.mac)
        assertEquals(15_000L, row.toman)
        assertEquals(100.0, row.share, 0.0)
    }
}
