package ir.parsavisions.xirouter.ui

import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.gestures.detectTapGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.CornerRadius
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.semantics.contentDescription
import androidx.compose.ui.semantics.semantics
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import ir.parsavisions.xirouter.ChartMath
import ir.parsavisions.xirouter.Format
import ir.parsavisions.xirouter.jalaliOf
import zed.rainxch.rikkaui.components.ui.text.Text
import zed.rainxch.rikkaui.components.ui.text.TextVariant

/** Compact, RTL-first Canvas charts. They never request more than their parent's phone width. */
private val Grid = Color(0x33FFFFFF)
private val ChartHeight = 132.dp

/** Timestamp-aware balance chart with quota reference, exhaustion marker and touch inspection. */
@Composable
fun BalanceTrend(
    samples: List<ChartMath.TimedValue>,
    quota: Double?,
    modifier: Modifier = Modifier,
    color: Color = StatusColors.up,
    caption: String = "",
) {
    val sorted = samples.sortedBy { it.ts }
    val exhaustion = ChartMath.projectedExhaustion(sorted)
    val displayEnd = maxOf(sorted.lastOrNull()?.ts ?: 0L, exhaustion ?: 0L)
    val displaySamples = if (sorted.isEmpty()) emptyList() else sorted +
        listOfNotNull(exhaustion?.let { ChartMath.TimedValue(it, 0.0) })
    val maxY = maxOf(quota ?: 0.0, sorted.maxOfOrNull { it.value } ?: 1.0, 1.0)
    val points = ChartMath.timedPlot(displaySamples, 0.0, maxY)
    val actualPoints = points.take(sorted.size)
    var selected by remember(sorted) { mutableIntStateOf(-1) }
    val description = buildString {
        append("نمودار موجودی بسته")
        sorted.lastOrNull()?.let { append("، آخرین مقدار ${Format.gbValue(it.value)} گیگابایت") }
        quota?.let { append("، سقف بسته ${Format.gbValue(it)} گیگابایت") }
        exhaustion?.let { append("، برآورد پایان ${jalaliDate(it)}") }
    }
    Column(modifier.fillMaxWidth().semantics { contentDescription = description }) {
        Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.padding(end = 6.dp).height(ChartHeight), verticalArrangement = Arrangement.SpaceBetween) {
                Text("${Format.gbValue(maxY)} گ", variant = TextVariant.Muted, style = androidx.compose.ui.text.TextStyle(fontSize = 9.sp))
                Text("${Format.gbValue(maxY / 2)} گ", variant = TextVariant.Muted, style = androidx.compose.ui.text.TextStyle(fontSize = 9.sp))
                Text("۰ گ", variant = TextVariant.Muted, style = androidx.compose.ui.text.TextStyle(fontSize = 9.sp))
            }
            Box(
                Modifier.weight(1f).height(ChartHeight)
                    .pointerInput(sorted) { detectTapGestures { selected = ChartMath.nearestIndex(sorted, it.x / size.width) } }
                    .pointerInput(sorted) { detectDragGestures { change, _ -> selected = ChartMath.nearestIndex(sorted, change.position.x / size.width) } },
            ) {
                Canvas(Modifier.matchParentSize()) {
                    if (actualPoints.size < 2) return@Canvas
                    val w = size.width
                    val h = size.height
                    for (i in 0..2) drawLine(Grid, Offset(0f, h * i / 2), Offset(w, h * i / 2), 1f)
                    quota?.let {
                        val y = h * (1f - (it / maxY).toFloat().coerceIn(0f, 1f))
                        drawLine(StatusColors.info.copy(alpha = .75f), Offset(0f, y), Offset(w, y), 1.dp.toPx())
                    }
                    exhaustion?.let {
                        val start = displaySamples.first().ts
                        val span = (displayEnd - start).coerceAtLeast(1L)
                        val x = ((it - start).toFloat() / span) * w
                        drawLine(StatusColors.warning, Offset(x, 0f), Offset(x, h), 1.dp.toPx())
                        drawCircle(StatusColors.warning, 3.dp.toPx(), Offset(x, h))
                    }
                    val fill = Path().apply {
                        moveTo(actualPoints.first().first * w, h)
                        actualPoints.forEach { lineTo(it.first * w, (1f - it.second) * h) }
                        lineTo(actualPoints.last().first * w, h)
                        close()
                    }
                    drawPath(fill, Brush.verticalGradient(listOf(color.copy(alpha = .25f), Color.Transparent)))
                    val line = Path()
                    actualPoints.forEachIndexed { i, p ->
                        val x = p.first * w; val y = (1f - p.second) * h
                        if (i == 0) line.moveTo(x, y) else line.lineTo(x, y)
                    }
                    drawPath(line, color, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round))
                    if (selected in actualPoints.indices) {
                        val p = actualPoints[selected]
                        val x = p.first * w; val y = (1f - p.second) * h
                        drawLine(Color.White.copy(alpha = .7f), Offset(x, 0f), Offset(x, h), 1.dp.toPx())
                        drawCircle(color, 5.dp.toPx(), Offset(x, y))
                    }
                }
            }
        }
        Row(Modifier.fillMaxWidth().padding(start = 40.dp, top = 4.dp), horizontalArrangement = Arrangement.SpaceBetween) {
            Text(sorted.firstOrNull()?.let { jalaliDate(it.ts) } ?: "", variant = TextVariant.Muted)
            Text(exhaustion?.let { "پایان ${jalaliDate(it)}" } ?: sorted.lastOrNull()?.let { jalaliDate(it.ts) } ?: "", variant = TextVariant.Muted)
        }
        if (selected in sorted.indices) {
            val point = sorted[selected]
            Text("${jalaliDate(point.ts)} · ${Format.gbValue(point.value)} گیگابایت", variant = TextVariant.Small, modifier = Modifier.padding(top = 4.dp))
        } else if (caption.isNotEmpty()) Text(caption, variant = TextVariant.Muted, modifier = Modifier.padding(top = 4.dp))
    }
}

/** Generic line retained for non-balance cumulative history. */
@Composable
fun LineTrend(values: List<Double>, modifier: Modifier = Modifier, color: Color = StatusColors.up, caption: String = "") {
    val progress = remember { Animatable(0f) }
    LaunchedEffect(values) { progress.snapTo(0f); if (values.size > 1) progress.animateTo(1f, tween(260)) }
    val points = ChartMath.plot(values)
    Column(modifier.fillMaxWidth().semantics { contentDescription = caption.ifBlank { "نمودار روند" } }) {
        Canvas(Modifier.fillMaxWidth().height(ChartHeight)) {
            if (points.size < 2) return@Canvas
            for (i in 1..3) drawLine(Grid, Offset(0f, size.height * i / 4), Offset(size.width, size.height * i / 4), 1f)
            val n = (points.size * progress.value).toInt().coerceIn(2, points.size)
            val line = Path()
            points.take(n).forEachIndexed { i, p -> if (i == 0) line.moveTo(p.first * size.width, (1f - p.second) * size.height) else line.lineTo(p.first * size.width, (1f - p.second) * size.height) }
            drawPath(line, color, style = Stroke(2.5.dp.toPx(), cap = StrokeCap.Round))
        }
        if (caption.isNotEmpty()) Text(caption, variant = TextVariant.Muted, modifier = Modifier.padding(top = 4.dp))
    }
}

/** Phone-safe daily or mini columns. Labels are compacted instead of horizontally scrolling. */
@Composable
fun ColumnChart(
    values: List<Double>,
    modifier: Modifier = Modifier,
    color: Color = StatusColors.up,
    caption: String = "",
    labels: List<String> = emptyList(),
    labelEvery: Int = 1,
    mini: Boolean = false,
) {
    val maxV = (values.maxOrNull() ?: 1.0).coerceAtLeast(1e-6)
    val height = if (mini) 88.dp else ChartHeight
    Column(modifier.fillMaxWidth().semantics { contentDescription = caption.ifBlank { "نمودار ستونی، ${values.size} ستون" } }) {
        Canvas(Modifier.fillMaxWidth().height(height)) {
            if (values.isEmpty()) return@Canvas
            val slot = size.width / values.size
            values.forEachIndexed { i, v ->
                val barW = (slot * .62f).coerceAtMost(20.dp.toPx()).coerceAtLeast(2.dp.toPx())
                val barH = (v / maxV).toFloat() * size.height
                drawRoundRect(color, Offset(i * slot + (slot - barW) / 2, size.height - barH), Size(barW, barH), CornerRadius(3.dp.toPx(), 3.dp.toPx()))
            }
        }
        if (labels.isNotEmpty()) Row(Modifier.fillMaxWidth()) {
            labels.forEachIndexed { i, label ->
                Text(
                    if (i % labelEvery == 0) label else "",
                    variant = TextVariant.Muted,
                    style = androidx.compose.ui.text.TextStyle(fontSize = 9.sp),
                    maxLines = 1,
                    modifier = Modifier.weight(1f),
                )
            }
        }
        if (caption.isNotEmpty()) Text(caption, variant = TextVariant.Muted, modifier = Modifier.padding(top = 4.dp))
    }
}

/** Owed vs collection for all 12 Jalali months, with alternating compact month labels. */
@Composable
fun GroupedBars(
    labels: List<String>, first: List<Double>, second: List<Double>, modifier: Modifier = Modifier,
    firstColor: Color = StatusColors.warning, secondColor: Color = StatusColors.up,
    firstLabel: String = "بدهی", secondLabel: String = "وصول",
) {
    val n = labels.size
    val maxV = (first + second).maxOrNull()?.coerceAtLeast(1e-6) ?: 1.0
    Column(modifier.fillMaxWidth().semantics { contentDescription = "نمودار سالانه بدهی و وصول در ۱۲ ماه" }) {
        Row(horizontalArrangement = Arrangement.spacedBy(12.dp)) { StatusDot(firstColor, firstLabel); StatusDot(secondColor, secondLabel) }
        Canvas(Modifier.fillMaxWidth().height(ChartHeight).padding(top = 8.dp)) {
            if (n == 0) return@Canvas
            val slot = size.width / n
            val barW = (slot * .3f).coerceAtLeast(3.dp.toPx()).coerceAtMost(10.dp.toPx())
            repeat(n) { i ->
                val cx = i * slot + slot / 2
                val ha = (first.getOrElse(i) { 0.0 } / maxV * size.height).toFloat()
                val hb = (second.getOrElse(i) { 0.0 } / maxV * size.height).toFloat()
                drawRoundRect(firstColor, Offset(cx - barW - 1, size.height - ha), Size(barW, ha), CornerRadius(2.dp.toPx()))
                drawRoundRect(secondColor, Offset(cx + 1, size.height - hb), Size(barW, hb), CornerRadius(2.dp.toPx()))
            }
        }
        Row(Modifier.fillMaxWidth()) {
            labels.forEach { label ->
                Text(
                    label.take(2),
                    variant = TextVariant.Muted,
                    style = androidx.compose.ui.text.TextStyle(fontSize = 8.sp),
                    maxLines = 1,
                    modifier = Modifier.weight(1f),
                )
            }
        }
    }
}

@Composable
private fun StatusDot(color: Color, label: String) {
    Row(verticalAlignment = Alignment.CenterVertically) {
        Canvas(Modifier.size(10.dp)) { drawCircle(color) }
        Text(label, variant = TextVariant.Muted, modifier = Modifier.padding(start = 4.dp))
    }
}

private fun jalaliDate(ts: Long): String {
    val date = jalaliOf(ir.parsavisions.xirouter.tehranDay(ts))
    return Format.faDigits("${date.month}/${date.day}")
}
