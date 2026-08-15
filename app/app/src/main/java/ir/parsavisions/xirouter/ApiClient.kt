package ir.parsavisions.xirouter

import android.util.Base64
import kotlinx.serialization.encodeToString
import kotlinx.serialization.json.Json
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import java.net.URLEncoder
import java.util.concurrent.TimeUnit

class ApiException(val status: Int, message: String) : Exception(message)
class UnauthorizedException : Exception("unauthorized")
class UnreachableException(cause: Throwable? = null) : Exception("router unreachable", cause)

/** Thin HTTP+JSON client over the Xirouter Router API. Blocking; call off the UI thread. */
object ApiClient {
    val json = Json {
        ignoreUnknownKeys = true
        encodeDefaults = true
        explicitNulls = false
    }

    private val client = OkHttpClient.Builder()
        .connectTimeout(4, TimeUnit.SECONDS)
        .readTimeout(8, TimeUnit.SECONDS)
        .build()

    inline fun <reified T> get(base: String, token: String, path: String, vararg query: Pair<String, String>): T {
        val body = request(base, token, "GET", path, null, query.toList())
        return json.decodeFromString(body)
    }

    inline fun <reified T> post(base: String, token: String, path: String, body: Map<String, Any?>): T {
        val resp = request(base, token, "POST", path, json.encodeToString(body), emptyList())
        return json.decodeFromString(resp)
    }

    @PublishedApi
    internal fun request(
        base: String, token: String, method: String, path: String,
        body: String?, query: List<Pair<String, String>>,
    ): String {
        val url = base.trimEnd('/') + path +
            if (query.isEmpty()) "" else
                "?" + query.joinToString("&") { "${it.first}=${URLEncoder.encode(it.second, "UTF-8")}" }
        // Auth: HTTP Basic. The router's uhttpd does NOT forward custom X-*
        // headers to CGI, so the token rides the standard Authorization header
        // (username "xirouter", token is the password).
        val auth = "Basic " + Base64.encodeToString(
            "xirouter:$token".toByteArray(Charsets.UTF_8), Base64.NO_WRAP
        )
        val reqBuilder = Request.Builder()
            .url(url)
            .header("Authorization", auth)
        if (body != null) {
            reqBuilder.method(method, body.toRequestBody("application/json; charset=utf-8".toMediaType()))
        } else {
            reqBuilder.method(method, null)
        }
        return try {
            client.newCall(reqBuilder.build()).execute().use { resp ->
                when (resp.code) {
                    in 200..299 -> resp.body?.string().orEmpty()
                    401 -> throw UnauthorizedException()
                    else -> throw ApiException(resp.code, resp.body?.string().orEmpty())
                }
            }
        } catch (e: ApiException) {
            throw e
        } catch (e: UnauthorizedException) {
            throw e
        } catch (e: Exception) {
            e.rethrowIfCancellation()
            throw UnreachableException(e)
        }
    }
}
