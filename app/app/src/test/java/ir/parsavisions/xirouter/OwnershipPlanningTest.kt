package ir.parsavisions.xirouter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class OwnershipPlanningTest {
    @Test fun correctionRejectsOverlapAndListsAffectedJalaliMonths() {
        val start = jalaliDay(1405, 1, 29)
        val end = jalaliDay(1405, 2, 3)
        val plan = OwnershipPlanning.correction(
            OwnershipCorrectionRequest("mac", "new", start, end),
            listOf(OwnershipRange("mac", "old", jalaliDay(1405, 1, 1), jalaliDay(1405, 2, 1))),
            listOf(start, jalaliDay(1405, 2, 1)),
        )
        assertEquals(1, plan.conflicts.size)
        assertEquals(setOf("1405/01", "1405/02"), plan.affectedMonthKeys)
        assertTrue(plan.valid)
    }

    @Test fun correctionRejectsFutureStartAndIncludesSamePersonOverlap() {
        val today = jalaliDay(1405, 2, 1)
        val plan = OwnershipPlanning.correction(
            OwnershipCorrectionRequest("mac", "same", today + 1, null),
            listOf(OwnershipRange("mac", "same", today - 2, null)), emptyList(), today,
        )
        assertFalse(plan.valid)
        assertEquals(1, plan.conflicts.size)
    }

    @Test fun mergeRequiresExplicitChoiceForCompetingManualMoneyAndSumsScope() {
        val survivor = LedgerEntryEntity("m|a", "m", "a", 2.0, 7_700, 15_000, paidToman = 5_000, edited = true)
        val source = LedgerEntryEntity("m|b", "m", "b", 3.0, 7_700, 23_000, costOverride = 20_000, edited = true)
        val plan = PersonMergePlanning.preview(
            PersonMergeRequest("a", "b", MergeManualChoice.REQUIRE_EXPLICIT),
            listOf(DeviceSettingsEntity("mac", ownerPersonId = "b")),
            listOf(OwnershipHistoryEntity("h", "mac", "b", 1)),
            listOf(survivor, source),
        )
        assertFalse(plan.canApply)
        assertEquals(1, plan.currentDeviceCount)
        assertEquals(1, plan.historyCount)
        assertEquals(setOf("m"), plan.affectedMonthKeys)
    }

    @Test fun suggestionConfidenceIsStableAndExplainable() {
        assertEquals(SuggestionConfidence.HIGH, OwnerSuggestion("p", 10.0, setOf(SuggestionSignal.HISTORY)).confidence)
        assertEquals(SuggestionConfidence.MEDIUM, OwnerSuggestion("p", 4.0, setOf(SuggestionSignal.NAME)).confidence)
        assertEquals(SuggestionConfidence.LOW, OwnerSuggestion("p", 1.5, setOf(SuggestionSignal.OUI)).confidence)
    }
}
