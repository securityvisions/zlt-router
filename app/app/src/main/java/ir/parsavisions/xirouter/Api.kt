package ir.parsavisions.xirouter

import kotlinx.serialization.Serializable

// DTOs mirror the Router API contract (API_CONTRACT.md). Every field is nullable
// with a default so a growing server never crashes an older app.

@Serializable
data class StatusDto(
    val uptime: String? = null,
    val load: String? = null,
    val ram: RamDto? = null,
    val temp_c: Int? = null,
    val disk: DiskDto? = null,
    val proxy: ProxyDto? = null,
)

@Serializable data class RamDto(val used_mb: Int? = null, val total_mb: Int? = null)
@Serializable data class DiskDto(val pct: Int? = null, val free: String? = null)
@Serializable data class ProxyDto(val state: String? = null, val latency_s: Double? = null, val node: String? = null)

@Serializable data class UsageRow(val name: String = "", val mac: String = "", val gb: Double = 0.0)
@Serializable data class UsageResponse(val period: String = "today", val rows: List<UsageRow> = emptyList())

@Serializable data class CostRow(
    val name: String = "", val mac: String = "", val gb: Double = 0.0,
    val toman: Long = 0, val share: Double = 0.0,
)
@Serializable data class CostResponse(
    val rate_full: Long = 7700,
    val rows: List<CostRow> = emptyList(),
    val total_gb: Double = 0.0,
    val total_toman: Long = 0,
)
@Serializable data class BillResponse(
    val period: String = "",
    val rate_full: Long = 7700,
    val rows: List<CostRow> = emptyList(),
    val total_gb: Double = 0.0,
    val total_toman: Long = 0,
)

@Serializable data class MainPlan(
    val quota: Int? = null, val remain: Double? = null, val pct: Int? = null,
    val expires: String? = null, val days: Int? = null,
)
@Serializable data class PackageFreshnessDto(val as_of_unix: Long = 0, val source: String? = null)
@Serializable data class DataPlanDto(
    val provider: String? = null, val subscriber: String? = null,
    val quota_gb: Double? = null, val remain_gb: Double? = null, val consumed_gb: Double? = null,
    val activation: String? = null, val expiry: String? = null, val status: String? = null,
    val freshness: PackageFreshnessDto? = null,
)
@Serializable data class PackageDto(
    val id: String = "", val provider: String? = null, val subscriber: String? = null,
    val type: String? = null, val name: String? = null, val category: String? = null,
    val window: String? = null, val quota_gb: Double? = null, val remain_gb: Double? = null,
    val consumed_gb: Double? = null, val activation: String? = null, val expiry: String? = null,
    val status: String? = null, val priority: Int = 0, val freshness: PackageFreshnessDto? = null,
)
@Serializable data class BalancePoint(val date: String = "", val gb: Double = 0.0)
@Serializable data class BalanceResponse(
    val cached: Boolean = false,
    val as_of_unix: Long = 0,
    val data_plan: DataPlanDto? = null,
    val packages: List<PackageDto> = emptyList(),
    val total_gb: Double? = null,
    val plans: Int? = null,
    val main: MainPlan? = null,
    val expired: Int = 0,
    val drain: String? = null,
    val series: List<BalancePoint> = emptyList(),
) {
    /** Aggregate values with a legacy fallback during the Router API rollout. */
    fun aggregate(): DataPlanDto? = data_plan ?: main?.let {
        DataPlanDto(quota_gb = it.quota?.toDouble(), remain_gb = it.remain,
            consumed_gb = it.quota?.toDouble()?.minus(it.remain ?: 0.0), expiry = it.expires)
    }
}

@Serializable data class ClientDto(
    val mac: String = "", val ip: String = "", val name: String = "",
    val hostname: String = "", val today_gb: Double = 0.0,
)
@Serializable data class ClientsResponse(val clients: List<ClientDto> = emptyList())

@Serializable data class WanDto(val rx_bytes: Long = 0, val tx_bytes: Long = 0)
@Serializable data class DeviceCounter(val mac: String = "", val rx_bytes: Long = 0, val tx_bytes: Long = 0)
@Serializable data class LiveResponse(
    val ts: Long = 0,
    val wan: WanDto = WanDto(),
    val devices: List<DeviceCounter> = emptyList(),
)

@Serializable data class HistoryPoint(val ts: String = "", val value: Double = 0.0)
@Serializable data class HistoryResponse(val kind: String = "", val points: List<HistoryPoint> = emptyList())

@Serializable data class DeviceDto(
    val mac: String = "", val name: String = "", val source: String = "",
    val watched: Boolean = false, val today_gb: Double = 0.0,
)
@Serializable data class DevicesResponse(val devices: List<DeviceDto> = emptyList())

@Serializable data class OkResponse(
    val ok: Boolean = false, val mac: String? = null, val name: String? = null,
    val watched: Boolean? = null, val node: String? = null,
    val url: String? = null, val result: String? = null,
)

// X28 4G/5G WAN link state (`GET /link`). Every field nullable-with-default so
// a growing server never crashes an older app.
@Serializable data class LinkFlow(val dl: Double = 0.0, val ul: Double = 0.0)
@Serializable data class LinkDto(
    val operator: String = "", val tech: String = "",
    val signal: Int? = null, val rsrp: Int? = null, val rsrp_5g: Int? = null,
    val band: String = "", val plmn: String = "",
    val flow: LinkFlow? = null,
) {
    val signalLabel: String get() = signal?.let { "$it/5" } ?: "—"
}
