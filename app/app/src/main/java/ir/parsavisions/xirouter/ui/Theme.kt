package ir.parsavisions.xirouter.ui

import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalLayoutDirection
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ir.parsavisions.xirouter.R
import zed.rainxch.rikkaui.foundation.RikkaStyle
import zed.rainxch.rikkaui.foundation.RikkaTheme
import zed.rainxch.rikkaui.foundation.RikkaMotionPresets
import zed.rainxch.rikkaui.foundation.RikkaAccentPreset
import zed.rainxch.rikkaui.foundation.RikkaSpacingPresets
import zed.rainxch.rikkaui.foundation.rikkaShapes
import zed.rainxch.rikkaui.foundation.rikkaTypography

// ── Fonts ────────────────────────────────────────────────────────────────────

/** Persian text face (full width, all weights). */
val Modam: FontFamily = FontFamily(Font(R.font.modam, FontWeight.Normal))

/** Same face; text rendered with it is meant to carry the tnum font feature. */
val ModamFigures: FontFamily = Modam

/** Merges [style] with the tabular-figure treatment used for every number. */
@Composable
fun fig(style: TextStyle): TextStyle =
    style.merge(TextStyle(fontFamily = ModamFigures, fontFeatureSettings = "tnum"))

// ── Status palette (monitoring colors) ───────────────────────────────────────

object StatusColors {
    val up = Color(0xFF22C55E)
    val warning = Color(0xFFF59E0B)
    val down = Color(0xFFEF4444)
    val info = Color(0xFF3B82F6)
    val urgent = Color(0xFFF97316)
}

// ── App theme ────────────────────────────────────────────────────────────────

/**
 * Xirouter's RikkaUi theme: the Slate palette with a Green accent (the app's
 * signature identity), a rounded/comfortable style, and forced RTL.
 */
@Composable
fun XirouterTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    accent: String = "green",
    density: String = "comfortable",
    reducedMotion: Boolean = false,
    preset: String = "calm",
    content: @Composable () -> Unit,
) {
    val style = RikkaStyle(
        shapes = rikkaShapes(radius = if (preset == "focused") 14.dp else 20.dp),
        spacing = if (density == "compact") RikkaSpacingPresets.compact() else RikkaSpacingPresets.comfortable(),
        motion = if (reducedMotion) RikkaMotionPresets.minimal() else if (preset == "vivid") RikkaMotionPresets.playful() else RikkaMotionPresets.snappy(),
        typeScale = 1.05f,
    )
    CompositionLocalProvider(LocalLayoutDirection provides LayoutDirection.Rtl) {
        val base = zed.rainxch.rikkaui.foundation.RikkaPalette.Slate.resolve(darkTheme)
        val accentPreset = when (accent) {
            "blue" -> RikkaAccentPreset.Blue
            "violet" -> RikkaAccentPreset.Violet
            "orange" -> RikkaAccentPreset.Orange
            "rose" -> RikkaAccentPreset.Rose
            else -> RikkaAccentPreset.Green
        }
        val colors = accentPreset.applyTo(base, darkTheme)
        RikkaTheme(
            colors = colors,
            style = style,
            typography = rikkaTypography(fontFamily = Modam, scale = style.typeScale),
            content = content,
        )
    }
}

/** Convenience accessor for the current Rikka tokens inside app composables. */
object AppTheme {
    @Composable
    @androidx.compose.runtime.ReadOnlyComposable
    fun colors() = RikkaTheme.colors

    @Composable
    @androidx.compose.runtime.ReadOnlyComposable
    fun spacing() = RikkaTheme.spacing

    @Composable
    @androidx.compose.runtime.ReadOnlyComposable
    fun shapes() = RikkaTheme.shapes

    @Composable
    @androidx.compose.runtime.ReadOnlyComposable
    fun motion() = RikkaTheme.motion

    val status get() = StatusColors
}