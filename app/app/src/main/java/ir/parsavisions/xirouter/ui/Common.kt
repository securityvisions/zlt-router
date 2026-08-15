package ir.parsavisions.xirouter.ui

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.BoxScope
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.ColumnScope
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.RowScope
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.heightIn
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Warning
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.KeyboardType
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.unit.isSpecified
import zed.rainxch.rikkaui.components.ui.alert.Alert
import zed.rainxch.rikkaui.components.ui.alert.AlertDescription
import zed.rainxch.rikkaui.components.ui.alert.AlertTitle
import zed.rainxch.rikkaui.components.ui.alert.AlertVariant
import zed.rainxch.rikkaui.components.ui.alertdialog.AlertDialog
import zed.rainxch.rikkaui.components.ui.alertdialog.AlertDialogAction
import zed.rainxch.rikkaui.components.ui.alertdialog.AlertDialogActionVariant
import zed.rainxch.rikkaui.components.ui.alertdialog.AlertDialogCancel
import zed.rainxch.rikkaui.components.ui.alertdialog.AlertDialogFooter
import zed.rainxch.rikkaui.components.ui.alertdialog.AlertDialogHeader
import zed.rainxch.rikkaui.components.ui.card.Card
import zed.rainxch.rikkaui.components.ui.card.CardVariant
import zed.rainxch.rikkaui.components.ui.icon.Icon
import zed.rainxch.rikkaui.components.ui.input.Input
import zed.rainxch.rikkaui.components.ui.progress.Progress
import zed.rainxch.rikkaui.components.ui.separator.Separator
import zed.rainxch.rikkaui.components.ui.skeleton.Skeleton
import zed.rainxch.rikkaui.components.ui.text.Text
import zed.rainxch.rikkaui.components.ui.text.TextVariant
import zed.rainxch.rikkaui.components.ui.button.IconButton
import zed.rainxch.rikkaui.foundation.RikkaTheme

// ── Surfaces ─────────────────────────────────────────────────────────────────

/** Adaptive phone gutter and readable tablet width for shared page-level content. */
@Composable
fun AdaptiveContent(
    modifier: Modifier = Modifier,
    content: @Composable BoxScope.() -> Unit,
) {
    BoxWithConstraints(modifier.fillMaxWidth()) {
        val gutter = when {
            maxWidth < 360.dp -> 12.dp
            maxWidth < 600.dp -> 16.dp
            else -> 24.dp
        }
        Box(
            Modifier
                .fillMaxWidth()
                .widthIn(max = 720.dp)
                .align(Alignment.TopCenter)
                .padding(horizontal = gutter),
            content = content,
        )
    }
}

/** Shared 48dp minimum for tappable list rows. */
fun Modifier.touchTarget(): Modifier = this.heightIn(min = 48.dp)

/** The standard content card — RikkaUi's Card with comfortable padding. */
@Composable
fun Panel(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(
        modifier = modifier.fillMaxWidth(),
        variant = CardVariant.Default,
        onClick = onClick,
    ) {
        Column(Modifier.padding(RikkaTheme.spacing.lg), content = content)
    }
}

/** A connected list group: rows with hairline separators inside one card. */
@Composable
fun ListCard(
    modifier: Modifier = Modifier,
    header: (@Composable () -> Unit)? = null,
    content: @Composable ColumnScope.() -> Unit,
) {
    Card(modifier = modifier.fillMaxWidth(), variant = CardVariant.Default) {
        if (header != null) {
            Column(Modifier.padding(horizontal = RikkaTheme.spacing.lg, vertical = RikkaTheme.spacing.md)) { header() }
            Separator(thickness = 0.5.dp)
        }
        content()
    }
}

/** One row inside a [ListCard]; the separator is drawn by the caller after each row. */
@Composable
fun RowScope.ListRow(
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
    content: @Composable RowScope.() -> Unit,
) {
    val base = modifier
        .fillMaxWidth()
        .touchTarget()
        .padding(horizontal = RikkaTheme.spacing.lg, vertical = RikkaTheme.spacing.md)
    val clickable = if (onClick != null) base.clickable(onClick = onClick) else base
    Row(
        modifier = clickable,
        verticalAlignment = Alignment.CenterVertically,
        content = content,
    )
}

@Composable
fun ListSeparator() {
    Separator(
        Modifier.padding(horizontal = RikkaTheme.spacing.lg),
        thickness = 0.5.dp,
    )
}

// ── Text helpers ─────────────────────────────────────────────────────────────

/** Section heading with the app's rhythm (air above, less below). */
@Composable
fun SectionTitle(text: String, modifier: Modifier = Modifier) {
    Text(
        text,
        variant = TextVariant.H4,
        modifier = modifier.padding(top = RikkaTheme.spacing.xl, bottom = RikkaTheme.spacing.md),
    )
}

/** A number with the tabular-figure treatment. */
@Composable
fun FigureText(
    text: String,
    modifier: Modifier = Modifier,
    variant: TextVariant = TextVariant.P,
    color: Color = Color.Unspecified,
    fontSize: androidx.compose.ui.unit.TextUnit = androidx.compose.ui.unit.TextUnit.Unspecified,
    fontWeight: FontWeight? = null,
    style: androidx.compose.ui.text.TextStyle = androidx.compose.ui.text.TextStyle.Default,
    maxLines: Int = Int.MAX_VALUE,
    overflow: TextOverflow = TextOverflow.Clip,
) {
    var s = fig(style)
    if (fontWeight != null) s = s.merge(androidx.compose.ui.text.TextStyle(fontWeight = fontWeight))
    if (fontSize.isSpecified) s = s.merge(androidx.compose.ui.text.TextStyle(fontSize = fontSize))
    Text(
        text = text,
        modifier = modifier,
        variant = variant,
        color = color,
        maxLines = maxLines,
        overflow = overflow,
        style = s,
    )
}

/** Label/value row. */
@Composable
fun DetailRow(label: String, value: String, modifier: Modifier = Modifier, bold: Boolean = false) {
    Row(modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
        Text(label, variant = TextVariant.Muted, modifier = Modifier.weight(1f))
        Text(
            value,
            variant = TextVariant.P,
            color = RikkaTheme.colors.onBackground,
            style = androidx.compose.ui.text.TextStyle(fontWeight = if (bold) FontWeight.Bold else FontWeight.Normal),
        )
    }
}

/** Colored pill (proxy UP/DOWN, paid status, …). */
@Composable
fun StatusPill(text: String, color: Color, modifier: Modifier = Modifier) {
    Text(
        text,
        variant = TextVariant.Small,
        color = Color.White,
        style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold),
        modifier = modifier
            .clip(RikkaTheme.shapes.full)
            .background(color)
            .padding(horizontal = RikkaTheme.spacing.md, vertical = RikkaTheme.spacing.xs),
    )
}

/** Person avatar — a colored circle with the first letter. */
@Composable
fun PersonAvatar(name: String, colorIndex: Int, modifier: Modifier = Modifier, size: Int = 40) {
    val palette = listOf(
        Color(0xFF3B82F6), Color(0xFF22C55E), Color(0xFFF59E0B), Color(0xFFEF4444),
        Color(0xFF8B5CF6), Color(0xFFEC4899), Color(0xFF14B8A6), Color(0xFFF97316),
    )
    val color = palette[((colorIndex % palette.size) + palette.size) % palette.size]
    val initial = name.trim().take(1).ifBlank { "؟" }
    Box(
        modifier = modifier.size(size.dp).clip(CircleShape).background(color),
        contentAlignment = Alignment.Center,
    ) {
        Text(initial, color = Color.White, style = androidx.compose.ui.text.TextStyle(fontWeight = FontWeight.Bold, fontSize = (size * 0.42).sp))
    }
}

/** Empty/offline placeholder. */
@Composable
fun EmptyState(icon: androidx.compose.ui.graphics.vector.ImageVector, title: String, hint: String, modifier: Modifier = Modifier) {
    Column(
        modifier = modifier.fillMaxWidth().padding(vertical = RikkaTheme.spacing.xxl),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.spacedBy(RikkaTheme.spacing.sm),
    ) {
        Icon(icon, contentDescription = null, tint = RikkaTheme.colors.onMuted)
        Text(title, variant = TextVariant.H4, textAlign = TextAlign.Center)
        Text(hint, variant = TextVariant.Muted, textAlign = TextAlign.Center)
    }
}

/** Destructive error banner with a dismiss. */
@Composable
fun ErrorCard(message: String?, onDismiss: () -> Unit) {
    if (message == null) return
    Alert(
        modifier = Modifier.fillMaxWidth().padding(RikkaTheme.spacing.lg),
        variant = AlertVariant.Destructive,
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                AlertTitle("خطا")
                AlertDescription(message)
            }
            IconButton(
                icon = Icons.Filled.Close,
                contentDescription = "بستن خطا",
                onClick = onDismiss,
            )
        }
    }
}

/** Confirmation + immediate PIN challenge for destructive actions. */
@Composable
fun DestructiveActionDialog(
    title: String,
    description: String,
    configuredPin: String,
    onDismiss: () -> Unit,
    onConfirm: () -> Unit,
) {
    var pin by remember { mutableStateOf("") }
    var invalid by remember { mutableStateOf(false) }
    val configured = configuredPin.isNotBlank()
    AlertDialog(
        open = true,
        onDismiss = onDismiss,
        onConfirm = {},
        label = title,
        showDefaultActions = false,
        content = {
            AlertDialogHeader(
                title,
                description = if (configured) description else "برای انجام این کار ابتدا قفل برنامه را در تنظیمات فعال و پین را تعیین کنید.",
            )
            if (configured) {
                Input(
                    value = pin,
                    onValueChange = { if (it.length <= 8) { pin = it; invalid = false } },
                    placeholder = "پین قفل برنامه",
                    keyboardOptions = KeyboardOptions(keyboardType = KeyboardType.NumberPassword),
                    visualTransformation = PasswordVisualTransformation(),
                )
                if (invalid) Text("پین اشتباه است", color = RikkaTheme.colors.destructive)
            }
            AlertDialogFooter {
                AlertDialogCancel(onClick = onDismiss, text = "انصراف")
                if (configured) {
                    AlertDialogAction(
                        text = "تأیید و انجام",
                        onClick = {
                            if (pin == configuredPin) onConfirm() else invalid = true
                        },
                        variant = AlertDialogActionVariant.Destructive,
                    )
                }
            }
        },
    )
}

// ── Gauges & tiny visuals ────────────────────────────────────────────────────

/** Arc gauge — green/amber/red zones with a figure label, like the old hero. */
@Composable
fun GaugeRing(pct: Int, modifier: Modifier = Modifier, label: String = "${pct}%", size: Int = 60) {
    val p = pct.coerceIn(0, 100)
    val color = when {
        p > 85 -> StatusColors.up
        p > 70 -> StatusColors.warning
        else -> StatusColors.down
    }
    Box(modifier.size(size.dp), contentAlignment = Alignment.Center) {
        Canvas(Modifier.size((size - 8).dp)) {
            val stroke = Stroke(width = 6.dp.toPx(), cap = StrokeCap.Round)
            drawArc(
                color = color.copy(alpha = 0.15f),
                startAngle = 135f, sweepAngle = 270f, useCenter = false, style = stroke,
            )
            drawArc(
                color = color,
                startAngle = 135f, sweepAngle = 270f * p / 100f, useCenter = false, style = stroke,
            )
        }
        FigureText(label, fontSize = 11.sp, fontWeight = FontWeight.Bold)
    }
}

/** Horizontal in-list ranking bar with value text. */
@Composable
fun RankRow(
    label: String,
    valueText: String,
    fraction: Float,
    modifier: Modifier = Modifier,
    onClick: (() -> Unit)? = null,
) {
    Column(modifier.fillMaxWidth().padding(vertical = RikkaTheme.spacing.xs)) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            Text(label, variant = TextVariant.P, maxLines = 1, overflow = TextOverflow.Ellipsis, modifier = Modifier.weight(1f))
            FigureText(valueText, variant = TextVariant.Small, fontWeight = FontWeight.Bold)
        }
        Spacer(Modifier.height(4.dp))
        val fraction2 = if (fraction.isFinite()) fraction.coerceIn(0f, 1f) else 0f
        Progress(progress = fraction2, height = 6.dp)
    }
}

/** A 60-point throughput sparkline — no axes, just shape. */
@Composable
fun Sparkline(points: List<Float>, modifier: Modifier = Modifier, color: Color = StatusColors.up) {
    Canvas(modifier) {
        if (points.size < 2) return@Canvas
        val w = size.width
        val h = size.height
        val max = (points.maxOrNull() ?: 1f).coerceAtLeast(1f)
        val step = w / (points.size - 1)
        val path = androidx.compose.ui.graphics.Path()
        points.forEachIndexed { i, v ->
            val x = i * step
            val y = h - (v / max) * (h - 4.dp.toPx()) - 2.dp.toPx()
            if (i == 0) path.moveTo(x, y) else path.lineTo(x, y)
        }
        drawPath(path, color, style = Stroke(width = 2.dp.toPx(), cap = StrokeCap.Round))
    }
}

/** Full-width skeleton block used while data loads. */
@Composable
fun SkeletonBlock(height: Int = 72, modifier: Modifier = Modifier) {
    Skeleton(
        modifier = modifier
            .fillMaxWidth()
            .height(height.dp)
            .padding(vertical = RikkaTheme.spacing.xs),
    )
}

/** A row of skeleton blocks for list loading. */
@Composable
fun SkeletonList(rows: Int = 5, modifier: Modifier = Modifier) {
    Column(modifier) {
        repeat(rows) { SkeletonBlock(44) }
    }
}