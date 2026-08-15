package ir.parsavisions.xirouter

import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.input.OffsetMapping
import androidx.compose.ui.text.input.TransformedText
import androidx.compose.ui.text.input.VisualTransformation

/**
 * Persian number formatting, bidirectional isolates, and visual transformations.
 * Adapted from chandtoman's Format.kt for a router-monitoring context.
 */
object Format {
    private const val FA_ZERO = '۰'
    private const val FA_SEP = '٬'   // Persian thousands separator (U+066C)
    private const val FA_DEC = '٫'   // Persian decimal separator (U+066B)
    private const val FA_MINUS = '−'  // minus sign (U+2212)

    // ── Digit conversion ─────────────────────────────────────────────────

    /** Convert Latin digits 0-9 to Persian ۰-۹; leave everything else. */
    fun faDigits(input: String): String = input.map { c ->
        if (c in '0'..'9') FA_ZERO + (c - '0') else c
    }.joinToString("")

    /** Full localization: digits, separators (٬ ٫ −). */
    fun faNum(input: String): String = input.map { c ->
        when {
            c in '0'..'9' -> FA_ZERO + (c - '0')
            c == ',' -> FA_SEP
            c == '.' -> FA_DEC
            c == '-' -> FA_MINUS
            else -> c
        }
    }.joinToString("")

    // ── Bidirectional isolates ───────────────────────────────────────────

    /**
     * Wraps in FSI/PDI to create an opaque bidi run.
     * Use around Latin tickers (e.g. "VLESS") embedded in Persian text.
     */
    fun bidi(s: String): String = "\u2068$s\u2069"

    /**
     * Wraps in LRI/PDI to force left-to-right.
     * Use for signed amounts where the sign must stay on the left: "+۱۶۵٫۱".
     */
    fun ltrFigure(s: String): String = "\u2066$s\u2069"

    // ── Grouping ─────────────────────────────────────────────────────────

    /** Group an integer with Latin separators ("1234567" → "1,234,567"). */
    fun group(n: Number): String {
        val s = n.toString()
        val neg = s.startsWith("-")
        val body = if (neg) s.drop(1) else s
        val grouped = body.reversed().chunked(3).joinToString(",").reversed()
        return (if (neg) "-" else "") + grouped
    }

    /** Toman with Persian separators: 15000 → ۱۵٬۰۰۰. */
    fun toman(value: Long): String = faNum(group(value))

    /** Toman with sign: e.g. "+۸٬۰۰۰" or "−۳٬۰۰۰". */
    fun tomanSigned(value: Long): String {
        val prefix = if (value > 0) "+" else if (value < 0) "" else ""
        return ltrFigure(prefix + faNum(group(kotlin.math.abs(value))))
    }

    // ── GB / percentage formatting ───────────────────────────────────────

    /** GB with up to 2 decimals, Persian digits: 1.25 → ۱٫۲۵, 2.0 → ۲. */
    fun gbValue(gb: Double): String = faNum(decimals(gb))

    /** Bytes → GB string: 1073741824 → ۱. */
    fun gb(bytes: Long): String = gbValue(bytes / 1_073_741_824.0)

    /** Percent with Persian digits: 97.0 → ۹۷٪. */
    fun pct(value: Double): String = faNum("%.0f%%".format(value))

    /** Compact percent for inline use: 97 → ۹۷٪. */
    fun pctCompact(value: Int): String = faNum("$value٪")

    // ── Compact / spoken amounts (ported from chandtoman) ─────────────────

    /** 1_234_000 → "۱٫۲ میلیون"; truncated, never rounded. */
    fun faCompact(toman: Double, dec: Int = 1, pad: Boolean = false): String {
        val n = kotlin.math.abs(toman)
        val (unit, div) = when {
            n >= 1_000_000_000_000.0 -> "همت" to 1_000_000_000_000.0
            n >= 1_000_000_000.0 -> "میلیارد" to 1_000_000_000.0
            n >= 1_000_000.0 -> "میلیون" to 1_000_000.0
            n >= 1_000.0 -> "هزار" to 1_000.0
            else -> return faNum(decimals(toman))
        }
        var f = 1.0
        repeat(if (div == 1_000.0) 0 else dec) { f *= 10 }
        val t = truncate(toman / div * f) / f
        val digits = faNum(decimals(t))
        return "$digits $unit"
    }

    private fun truncate(v: Double): Double {
        val t = v.toLong()
        return if (v >= 0) t.toDouble() else if (t * 1.0 == v) t.toDouble() else t.toDouble() - 1.0
    }

    private val ONES = arrayOf("", "یک", "دو", "سه", "چهار", "پنج", "شش", "هفت", "هشت", "نه")
    private val TEENS = arrayOf(
        "ده", "یازده", "دوازده", "سیزده", "چهارده",
        "پانزده", "شانزده", "هفده", "هجده", "نوزده",
    )
    private val TENS = arrayOf("", "", "بیست", "سی", "چهل", "پنجاه", "شصت", "هفتاد", "هشتاد", "نود")
    private val HUNDREDS =
        arrayOf("", "صد", "دویست", "سیصد", "چهارصد", "پانصد", "ششصد", "هفتصد", "هشتصد", "نهصد")
    private val SCALES = arrayOf("", "هزار", "میلیون", "میلیارد", "هزار میلیارد")

    /** 1..999 in words. */
    private fun tripleToWords(n: Int): String {
        val parts = mutableListOf<String>()
        val h = n / 100
        val r = n % 100
        if (h > 0) parts += HUNDREDS[h]
        when {
            r in 10..19 -> parts += TEENS[r - 10]
            else -> {
                if (r / 10 > 0) parts += TENS[r / 10]
                if (r % 10 > 0) parts += ONES[r % 10]
            }
        }
        return parts.joinToString(" و ")
    }

    /** The amount spelled out: 10_800_000 -> "ده میلیون و هشتصد هزار". Exact, never rounded. */
    fun faWords(value: Long): String {
        if (value == 0L) return "صفر"
        if (value < 0) return "منفی ${faWords(-value)}"
        val groups = mutableListOf<Int>()
        var v = value
        while (v > 0) {
            groups += (v % 1000).toInt()
            v /= 1000
        }
        if (groups.size > SCALES.size) return ""
        val parts = mutableListOf<String>()
        for (i in groups.indices.reversed()) {
            val g = groups[i]
            if (g == 0) continue
            val words = if (g == 1 && i == 1) "" else tripleToWords(g)
            parts += listOf(words, SCALES[i]).filter { it.isNotBlank() }.joinToString(" ")
        }
        return parts.joinToString(" و ")
    }

    /** Words for a Toman figure, or null when spelling it out would not help. */
    fun faWordsToman(value: Double): String? {
        if (value <= 0 || value >= 1e15) return null
        val words = faWords(value.toLong())
        return if (words.isBlank()) null else "$words تومان"
    }

    /**
     * Reads a number the way a Persian keyboard produces it: Persian (۰-۹) or Arabic-Indic
     * (٠-٩) digits, Persian decimal separator, thousands separators ignored.
     * Returns null on anything it doesn't understand — this is the money path.
     */
    fun parseAmount(input: String): Double? {
        val sb = StringBuilder()
        for (c in input) {
            when {
                c in '۰'..'۹' -> sb.append('0' + (c - '۰'))
                c in '٠'..'٩' -> sb.append('0' + (c - '٠'))
                c.isDigit() -> sb.append(c)
                c == '.' || c == '٫' -> sb.append('.')
                c == ',' || c == '،' || c == '٬' || c == ' ' || c == '‏' || c == 'ٔ' -> Unit
                else -> return null
            }
        }
        val s = sb.toString()
        if (s.isEmpty() || s == ".") return null
        return s.toDoubleOrNull()?.takeIf { it >= 0 && it.isFinite() }
    }

    // ── Internal helpers ─────────────────────────────────────────────────

    private fun decimals(v: Double): String {
        val rounded = Math.round(v * 100) / 100.0
        if (rounded == Math.floor(rounded)) return rounded.toLong().toString()
        return "%.2f".format(rounded).trimEnd('0')
    }

    // ── Persian VisualTransformation (thousands separator as you type) ───

    /**
     * Groups digits with Persian separators (٬) as the user types into a text field.
     * Caret offset mapping is handled so the cursor stays in the right place.
     */
    val GroupedNumber: VisualTransformation = object : VisualTransformation {
        override fun filter(text: AnnotatedString): TransformedText {
            val raw = text.text
            if (raw.isEmpty()) return TransformedText(text, OffsetMapping.Identity)

            val isNeg = raw.startsWith('-')
            val digits = raw.filter { it.isDigit() }
            if (digits.isEmpty()) return TransformedText(text, OffsetMapping.Identity)

            val groups = digits.reversed().chunked(3).joinToString(FA_SEP.toString()).reversed()
            val formatted = "${if (isNeg) FA_MINUS else ""}$groups"

            return TransformedText(
                AnnotatedString(formatted),
                PersianGroupOffset(raw, formatted),
            )
        }
    }

    /**
     * OffsetMapping for PersianGroupedNumber: maps offsets between the raw digit string
     * (with separators stripped) and the formatted string (with separators inserted).
     */
    private class PersianGroupOffset(private val raw: String, private val formatted: String) : OffsetMapping {
        private val rawDigits: List<Int> = raw.indices.filter { raw[it].isDigit() || raw[it] == '-' }
        private val fmtNonSep: List<Int> = formatted.indices.filter { formatted[it] != FA_SEP }

        override fun originalToTransformed(offset: Int): Int {
            val rawDigitIndex = rawDigits.indexOfFirst { it >= offset }.coerceAtLeast(0)
            return fmtNonSep.getOrNull(rawDigitIndex) ?: formatted.length
        }

        override fun transformedToOriginal(offset: Int): Int {
            val fmtIndex = fmtNonSep.indexOfFirst { it >= offset }.coerceAtLeast(0)
            return rawDigits.getOrNull(fmtIndex) ?: raw.length
        }
    }
}
