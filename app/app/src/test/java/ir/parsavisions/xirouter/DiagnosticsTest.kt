package ir.parsavisions.xirouter

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DiagnosticsTest {
    @Test fun `sanitizer removes forbidden private data`() {
        val private = "token=secret https://router.local/api 00:11:22:AA:BB:CC Authorization: Basic abc name=Parsa note=private"
        val clean = Diagnostics.sanitize(private)

        assertFalse(clean.contains("secret"))
        assertFalse(clean.contains("http"))
        assertFalse(clean.contains("00:11"))
        assertFalse(clean.contains("Parsa"))
        assertFalse(clean.contains("private"))
        assertTrue(clean.contains("[redacted]"))
    }

    @Test fun `bounded history prunes age then keeps newest limits`() {
        val now = 2_000_000_000_000L
        val crashes = (0 until 25).map { DiagnosticRecord(now - it, DiagnosticKind.Crash, operation = "poll") } +
            DiagnosticRecord(0, DiagnosticKind.Crash)
        val events = (0 until 205).map { DiagnosticRecord(now - it, DiagnosticKind.Operation, operation = "refresh") }

        val bounded = Diagnostics.bound(crashes + events, now)

        assertEquals(20, bounded.count { it.kind == DiagnosticKind.Crash })
        assertEquals(200, bounded.count { it.kind == DiagnosticKind.Operation })
        assertFalse(bounded.any { it.timestamp == 0L })
        assertEquals(now, bounded.maxOf { it.timestamp })
    }

    @Test fun `sanitized stack contains structure but not throwable message`() {
        val stack = Diagnostics.sanitizeStack(IllegalStateException("token=secret at https://router"))

        assertTrue(stack.contains("IllegalStateException"))
        assertFalse(stack.contains("secret"))
        assertFalse(stack.contains("https://"))
    }
}
