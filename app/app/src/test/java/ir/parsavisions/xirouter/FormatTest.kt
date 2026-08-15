package ir.parsavisions.xirouter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class FormatTest {

    @Test fun `compact toman - truncated not rounded`() {
        assertEquals("۱٫۲ میلیون", Format.faCompact(1_234_000.0))
        assertEquals("۱۲٫۵ میلیون", Format.faCompact(12_500_000.0))
        assertEquals("۳۳ هزار", Format.faCompact(33_400.0))
        assertEquals("۴۵۶", Format.faCompact(456.0))
        assertEquals("۲ میلیارد", Format.faCompact(2_100_000_000.0, dec = 0))
    }

    @Test fun `words - ten million eight hundred thousand`() {
        assertEquals("ده میلیون و هشتصد هزار", Format.faWords(10_800_000))
        assertEquals("هزار", Format.faWords(1_000))
        assertEquals("صفر", Format.faWords(0))
        assertEquals("منفی پانزده هزار", Format.faWords(-15_000))
    }

    @Test fun `words toman - amount is spelled with unit`() {
        assertEquals("پانزده هزار تومان", Format.faWordsToman(15_000.0))
        assertEquals("دو میلیون تومان", Format.faWordsToman(2_000_000.0))
        assertNull(Format.faWordsToman(0.0))
    }

    @Test fun `parseAmount accepts Persian and Arabic-Indic digits with separators`() {
        assertEquals(4_567.0, Format.parseAmount("۴٬۵۶۷")!!, 0.0)
        assertEquals(4_567.0, Format.parseAmount("٤٥٦٧")!!, 0.0)
        assertEquals(150.5, Format.parseAmount("۱۵۰٫۵")!!, 0.0)
        assertEquals(1_234.0, Format.parseAmount("1,234")!!, 0.0)
        assertNull(Format.parseAmount("۵۰۰ هزار"))
        assertNull(Format.parseAmount(""))
        assertNull(Format.parseAmount("."))
    }

    @Test fun `gbValue trims trailing zeros`() {
        assertEquals("۲", Format.gbValue(2.0))
        assertEquals("۱٫۲۵", Format.gbValue(1.25))
    }

    @Test fun `toman groups with Persian separator`() {
        assertEquals("۱۵٬۰۰۰", Format.toman(15_000))
        assertEquals("۱٬۲۳۴٬۵۶۷", Format.toman(1_234_567))
    }
}