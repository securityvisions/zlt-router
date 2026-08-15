package ir.parsavisions.xirouter

import android.content.Context
import kotlinx.coroutines.CancellationException
import kotlinx.serialization.Serializable
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import java.io.ByteArrayOutputStream
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

@Serializable
enum class DiagnosticKind { Crash, Operation }

/** Privacy-safe fields permitted in local diagnostics and the Support bundle. */
@Serializable
data class DiagnosticRecord(
    val timestamp: Long,
    val kind: DiagnosticKind,
    val appVersion: String = "",
    val route: String = "",
    val operation: String = "",
    val lifecycle: String = "",
    val sessionDurationMs: Long = 0,
    val memoryPressure: String = "",
    val dbCounts: Map<String, Int> = emptyMap(),
    val stack: String = "",
)

fun Exception.rethrowIfCancellation() { if (this is CancellationException) throw this }

suspend inline fun <T> cancellationAwareResult(crossinline block: suspend () -> T): Result<T> =
    try { Result.success(block()) } catch (e: Exception) { e.rethrowIfCancellation(); Result.failure(e) }

object Diagnostics {
    const val MAX_CRASHES = 20
    const val MAX_EVENTS = 200
    const val MAX_AGE_MS = 30L * 86_400_000L

    private val url = Regex("(?i)\\b(?:https?|wss?)://\\S+")
    private val mac = Regex("(?i)\\b(?:[0-9a-f]{2}[:-]){5}[0-9a-f]{2}\\b")
    private val sensitive = Regex("(?i)\\b(token|authorization|password|credential|name|alias|person|note|notification|body|raw(?:_?api)?)\\s*[:=]\\s*\\S+")

    fun sanitize(value: String): String = value
        .replace(url, "[redacted]")
        .replace(mac, "[redacted]")
        .replace(sensitive, "$1=[redacted]")
        .take(8_000)

    fun sanitizeStack(error: Throwable): String = buildString {
        append(error.javaClass.name)
        error.stackTrace.take(40).forEach { frame ->
            append("\n at ").append(frame.className).append('.').append(frame.methodName)
                .append('(').append(frame.fileName ?: "Unknown").append(':').append(frame.lineNumber).append(')')
        }
    }.let(::sanitize)

    fun bound(records: List<DiagnosticRecord>, now: Long): List<DiagnosticRecord> {
        val recent = records.filter { it.timestamp >= now - MAX_AGE_MS }.sortedByDescending { it.timestamp }
        return (recent.filter { it.kind == DiagnosticKind.Crash }.take(MAX_CRASHES) +
            recent.filter { it.kind == DiagnosticKind.Operation }.take(MAX_EVENTS)).sortedByDescending { it.timestamp }
    }
}

/** Bounded private storage and ZIP generation for manual Support bundle export. */
class DiagnosticStore(private val context: Context) {
    private val appVersion get() = runCatching { context.packageManager.getPackageInfo(context.packageName, 0).versionName }.getOrNull().orEmpty()
    private val file get() = context.filesDir.resolve("diagnostics.json")
    private val json = Json { ignoreUnknownKeys = true; encodeDefaults = true }

    @Synchronized fun records(): List<DiagnosticRecord> = runCatching {
        json.decodeFromString<List<DiagnosticRecord>>(file.readText())
    }.getOrDefault(emptyList()).let { Diagnostics.bound(it, System.currentTimeMillis()) }

    @Synchronized fun add(record: DiagnosticRecord) {
        val safe = record.copy(
            appVersion = appVersion,
            route = Diagnostics.sanitize(record.route),
            operation = Diagnostics.sanitize(record.operation),
            lifecycle = Diagnostics.sanitize(record.lifecycle),
            memoryPressure = Diagnostics.sanitize(record.memoryPressure),
            stack = Diagnostics.sanitize(record.stack),
        )
        runCatching { file.writeText(json.encodeToString(Diagnostics.bound(records() + safe, System.currentTimeMillis()))) }
    }

    fun preview(): String {
        val all = records()
        return "نسخه ${appVersion} · ${all.count { it.kind == DiagnosticKind.Crash }} خطا · ${all.count { it.kind == DiagnosticKind.Operation }} رویداد · بدون نشانی، توکن، نام یا محتوای اعلان"
    }

    fun bundle(): ByteArray {
        val all = records()
        val manifest = SupportBundleManifest(
            appVersion = appVersion,
            createdAt = System.currentTimeMillis(),
            crashCount = all.count { it.kind == DiagnosticKind.Crash },
            eventCount = all.count { it.kind == DiagnosticKind.Operation },
            exclusions = listOf("credentials", "raw_api", "url", "mac", "names", "person_notes", "notification_contents"),
        )
        return ByteArrayOutputStream().also { bytes ->
            ZipOutputStream(bytes).use { zip ->
                zip.putNextEntry(ZipEntry("manifest.json")); zip.write(json.encodeToString(manifest).toByteArray()); zip.closeEntry()
                zip.putNextEntry(ZipEntry("diagnostics.json")); zip.write(json.encodeToString(all).toByteArray()); zip.closeEntry()
            }
        }.toByteArray()
    }
}

@Serializable
data class SupportBundleManifest(
    val appVersion: String,
    val createdAt: Long,
    val crashCount: Int,
    val eventCount: Int,
    val exclusions: List<String>,
)
