package ir.parsavisions.xirouter.ui

import android.content.Context
import android.net.Uri
import kotlinx.coroutines.CancellationException

/** Write CSV bytes to a SAF-created document (the caller owns the launcher). */
object Export {
    fun writeCsv(context: Context, uri: Uri, text: String): Boolean = try {
        context.contentResolver.openOutputStream(uri)?.use { out ->
            // BOM so Excel reads the UTF-8 Persian headers correctly.
            out.write("\uFEFF".toByteArray(Charsets.UTF_8))
            out.write(text.toByteArray(Charsets.UTF_8))
        } != null
    } catch (e: Exception) {
        if (e is CancellationException) throw e
        false
    }

    fun writeBytes(context: Context, uri: Uri, bytes: ByteArray): Boolean = try {
        context.contentResolver.openOutputStream(uri)?.use { it.write(bytes) } != null
    } catch (e: Exception) {
        if (e is CancellationException) throw e
        false
    }
}