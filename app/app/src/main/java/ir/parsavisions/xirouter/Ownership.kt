package ir.parsavisions.xirouter

/** Public, Android-free ownership planning seam used by UI previews and lifecycle tests. */
data class OwnershipRange(val mac: String, val personId: String, val startDay: Long, val endDay: Long?)
data class OwnershipCorrectionRequest(val mac: String, val personId: String, val startDay: Long, val endDay: Long?)
data class OwnershipConflict(val range: OwnershipRange)

data class OwnershipCorrectionPlan(
    val request: OwnershipCorrectionRequest,
    val conflicts: List<OwnershipConflict>,
    val affectedMonthKeys: Set<String>,
    val today: Long = Long.MAX_VALUE,
) {
    val valid: Boolean get() = request.startDay <= today && (request.endDay == null || request.endDay > request.startDay)
}

object OwnershipPlanning {
    fun correction(
        request: OwnershipCorrectionRequest,
        existing: List<OwnershipRange>,
        usageDays: List<Long>,
        today: Long = Long.MAX_VALUE,
    ): OwnershipCorrectionPlan {
        val conflicts = existing.filter { range ->
            range.mac == request.mac && overlaps(request.startDay, request.endDay, range.startDay, range.endDay)
        }.map(::OwnershipConflict)
        val days = buildSet {
            add(request.startDay)
            request.endDay?.minus(1)?.let(::add)
            usageDays.filter { it >= request.startDay && (request.endDay == null || it < request.endDay) }.forEach(::add)
        }
        return OwnershipCorrectionPlan(request, conflicts, days.mapTo(mutableSetOf()) {
            val j = jalaliOf(it); MonthAttribution.key(j.year, j.month)
        }, today)
    }

    private fun overlaps(aStart: Long, aEnd: Long?, bStart: Long, bEnd: Long?): Boolean =
        aStart < (bEnd ?: Long.MAX_VALUE) && bStart < (aEnd ?: Long.MAX_VALUE)
}

enum class MergeManualChoice { REQUIRE_EXPLICIT, SURVIVOR, SOURCE, SUM_PAYMENTS }
data class PersonMergeRequest(val survivorId: String, val sourceId: String, val manualChoice: MergeManualChoice)
data class PersonMergeConflict(val monthKey: String, val survivorEdited: Boolean, val sourceEdited: Boolean)
data class PersonMergePlan(
    val request: PersonMergeRequest,
    val affectedMonthKeys: Set<String>,
    val currentDeviceCount: Int,
    val historyCount: Int,
    val conflicts: List<PersonMergeConflict>,
) {
    val canApply: Boolean get() = request.survivorId != request.sourceId &&
        (conflicts.isEmpty() || request.manualChoice != MergeManualChoice.REQUIRE_EXPLICIT)
}

object PersonMergePlanning {
    fun preview(
        request: PersonMergeRequest,
        currentDevices: List<DeviceSettingsEntity>,
        history: List<OwnershipHistoryEntity>,
        entries: List<LedgerEntryEntity>,
    ): PersonMergePlan {
        val relevant = entries.filter { it.personId == request.survivorId || it.personId == request.sourceId }
        val conflicts = relevant.groupBy { it.monthKey }.mapNotNull { (month, rows) ->
            val survivor = rows.find { it.personId == request.survivorId }
            val source = rows.find { it.personId == request.sourceId }
            if (survivor != null && source != null && survivor.hasManualMoney() && source.hasManualMoney())
                PersonMergeConflict(month, survivor.edited, source.edited) else null
        }
        return PersonMergePlan(
            request,
            relevant.mapTo(mutableSetOf()) { it.monthKey },
            currentDevices.count { it.ownerPersonId == request.sourceId },
            history.count { it.personId == request.sourceId },
            conflicts,
        )
    }

    private fun LedgerEntryEntity.hasManualMoney() = edited || costOverride != null || paidToman > 0 || note.isNotBlank()
}

enum class SuggestionConfidence { HIGH, MEDIUM, LOW }
val OwnerSuggestion.confidence: SuggestionConfidence get() = when {
    score >= 10 -> SuggestionConfidence.HIGH
    score >= 4 -> SuggestionConfidence.MEDIUM
    else -> SuggestionConfidence.LOW
}
