package zed.rainxch.rikkaui.components.ui.scaffold

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.safeDrawing
import androidx.compose.foundation.layout.safeGestures
import androidx.compose.foundation.layout.union
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.SubcomposeLayout
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.LayoutDirection
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.offset
import zed.rainxch.rikkaui.foundation.LocalContentColor
import zed.rainxch.rikkaui.foundation.RikkaTheme

// ─── Subcompose Slots ──────────────────────────────────────

@Immutable
private enum class ScaffoldSlot {
    TopBar,
    BottomBar,
    Fab,
    SnackbarHost,
    ToastHost,
    Content,
}

// ─── FAB Position ──────────────────────────────────────────

@kotlin.jvm.JvmInline
public value class FabPosition internal constructor(
    @Suppress("unused") private val value: Int,
) {
    public companion object {
        /** Position FAB at the bottom of the screen at the start, above the bottom bar. */
        public val Start: FabPosition = FabPosition(0)

        /** Position FAB at the bottom of the screen in the center, above the bottom bar. */
        public val Center: FabPosition = FabPosition(1)

        /** Position FAB at the bottom of the screen at the end, above the bottom bar. */
        public val End: FabPosition = FabPosition(2)

        /** Position FAB at the bottom of the screen at the end, overlaying the bottom bar. */
        public val EndOverlay: FabPosition = FabPosition(3)
    }

    override fun toString(): String =
        when (this) {
            Start -> "FabPosition.Start"
            Center -> "FabPosition.Center"
            End -> "FabPosition.End"
            else -> "FabPosition.EndOverlay"
        }
}

// ─── Content Window Insets ──────────────────────────────────

@Immutable
public data class ScaffoldWindowInsets(
    public val left: Dp = 0.dp,
    public val top: Dp = 0.dp,
    public val right: Dp = 0.dp,
    public val bottom: Dp = 0.dp,
)

// ─── Component ─────────────────────────────────────────────

/**
 * Layout scaffold that manages top bar, bottom bar, FAB, snackbar, toast, and body content slots.
 *
 * Uses [SubcomposeLayout] to measure bars first and provide correct [PaddingValues] to the body.
 * Toasts are rendered as the highest layer, always on top of all other content.
 * Provides [LocalContentColor] from [contentColor] to all children.
 *
 * @param modifier [Modifier] applied to the scaffold root.
 * @param topBar Composable slot for the top app bar. Defaults to empty.
 * @param bottomBar Composable slot for the bottom navigation bar. Defaults to empty.
 * @param floatingActionButton Composable slot for the FAB. Defaults to empty.
 * @param floatingActionButtonPosition [FabPosition] controlling FAB placement. Defaults to [FabPosition.End].
 * @param snackbarHost Composable slot for the snackbar host. Defaults to empty.
 * @param toastHost Composable slot for the toast host overlay. Defaults to empty.
 * @param containerColor Background color of the scaffold. Defaults to [RikkaTheme.colors.background].
 * @param contentColor Foreground content color provided via [LocalContentColor]. Defaults to [RikkaTheme.colors.onBackground].
 * @param contentWindowInsets [ScaffoldWindowInsets] for additional padding around content. Defaults to zero insets.
 * @param content Body content lambda receiving [PaddingValues] that account for top bar and bottom bar heights.
 */
@Composable
public fun Scaffold(
    modifier: Modifier = Modifier,
    topBar: @Composable () -> Unit = {},
    bottomBar: @Composable () -> Unit = {},
    floatingActionButton: @Composable () -> Unit = {},
    floatingActionButtonPosition: FabPosition = FabPosition.End,
    snackbarHost: @Composable () -> Unit = {},
    toastHost: @Composable () -> Unit = {},
    containerColor: Color = RikkaTheme.colors.background,
    contentColor: Color = RikkaTheme.colors.onBackground,
    contentWindowInsets: ScaffoldWindowInsets = ScaffoldWindowInsets(),
    content: @Composable (PaddingValues) -> Unit,
) {
    val fabSpacing = RikkaTheme.spacing.md

    // Smart PaddingValues: remembered once, backing state updated during
    // measurement (before body subcomposition) to avoid recomposition.
    val contentPadding =
        remember {
            MutableScaffoldPaddingValues(PaddingValues(0.dp))
        }

    CompositionLocalProvider(LocalContentColor provides contentColor) {
        SubcomposeLayout(
            modifier =
                modifier
                    .fillMaxSize()
                    .background(containerColor)
                    .windowInsetsPadding(WindowInsets.safeDrawing.union(WindowInsets.safeGestures)),
        ) { constraints ->
            val layoutWidth = constraints.maxWidth
            val layoutHeight = constraints.maxHeight
            val fabPadding = fabSpacing.roundToPx()

            val insetLeft = contentWindowInsets.left.roundToPx()
            val insetTop = contentWindowInsets.top.roundToPx()
            val insetRight = contentWindowInsets.right.roundToPx()
            val insetBottom = contentWindowInsets.bottom.roundToPx()

            val looseConstraints = constraints.copy(minWidth = 0, minHeight = 0)

            // ── Measure top bar ────────────────────────────────
            val topBarPlaceables =
                subcompose(ScaffoldSlot.TopBar, topBar)
                    .map { it.measure(looseConstraints) }
            val topBarHeight = topBarPlaceables.maxOfOrNull { it.height } ?: 0

            // ── Measure bottom bar ─────────────────────────────
            val bottomBarPlaceables =
                subcompose(ScaffoldSlot.BottomBar, bottomBar)
                    .map { it.measure(looseConstraints) }
            val bottomBarHeight = bottomBarPlaceables.maxOfOrNull { it.height } ?: 0
            val isBottomBarEmpty = bottomBarHeight == 0

            // ── Measure FAB ────────────────────────────────────
            val fabPlaceables =
                subcompose(ScaffoldSlot.Fab, floatingActionButton)
                    .map {
                        it.measure(
                            looseConstraints.offset(
                                horizontal = -(insetLeft + insetRight),
                                vertical = -insetBottom,
                            ),
                        )
                    }
            val fabWidth = fabPlaceables.maxOfOrNull { it.width } ?: 0
            val fabHeight = fabPlaceables.maxOfOrNull { it.height } ?: 0
            val isFabEmpty = fabWidth == 0 && fabHeight == 0

            // ── FAB placement ──────────────────────────────────
            val fabLeftOffset =
                if (!isFabEmpty) {
                    when (floatingActionButtonPosition) {
                        FabPosition.Start -> {
                            if (layoutDirection == LayoutDirection.Ltr) {
                                fabPadding + insetLeft
                            } else {
                                layoutWidth - fabPadding - fabWidth - insetRight
                            }
                        }

                        FabPosition.Center -> {
                            (layoutWidth - fabWidth + insetLeft - insetRight) / 2
                        }

                        FabPosition.End,
                        FabPosition.EndOverlay,
                        -> {
                            if (layoutDirection == LayoutDirection.Ltr) {
                                layoutWidth - fabPadding - fabWidth - insetRight
                            } else {
                                fabPadding + insetLeft
                            }
                        }

                        else -> {
                            (layoutWidth - fabWidth + insetLeft - insetRight) / 2
                        }
                    }
                } else {
                    0
                }

            val fabOffsetFromBottom =
                if (!isFabEmpty) {
                    if (isBottomBarEmpty || floatingActionButtonPosition == FabPosition.EndOverlay) {
                        fabHeight + fabPadding + insetBottom
                    } else {
                        bottomBarHeight + fabHeight + fabPadding
                    }
                } else {
                    0
                }

            // ── Measure snackbar host ──────────────────────────
            val snackbarPlaceables =
                subcompose(ScaffoldSlot.SnackbarHost, snackbarHost)
                    .map { it.measure(looseConstraints) }
            val snackbarWidth = snackbarPlaceables.maxOfOrNull { it.width } ?: 0
            val snackbarHeight = snackbarPlaceables.maxOfOrNull { it.height } ?: 0

            val snackbarOffsetFromBottom =
                if (snackbarHeight != 0) {
                    snackbarHeight +
                        (
                            if (fabOffsetFromBottom > 0) {
                                fabOffsetFromBottom
                            } else if (!isBottomBarEmpty) {
                                bottomBarHeight
                            } else {
                                insetBottom
                            }
                        )
                } else {
                    0
                }

            // ── Measure toast host (full-screen overlay) ────────
            val toastPlaceables =
                subcompose(ScaffoldSlot.ToastHost, toastHost)
                    .map { it.measure(looseConstraints) }

            // ── Update content padding before measuring body ───
            contentPadding.paddingHolder =
                PaddingValues(
                    start = contentWindowInsets.left,
                    top = topBarHeight.toDp() + contentWindowInsets.top,
                    end = contentWindowInsets.right,
                    bottom = bottomBarHeight.toDp() + contentWindowInsets.bottom,
                )

            // Content owns the full scaffold bounds and consumes the supplied padding once.
            val contentPlaceables =
                subcompose(ScaffoldSlot.Content) {
                    content(contentPadding)
                }.map { it.measure(looseConstraints) }

            // ── Place everything (order = drawing order) ───────
            layout(layoutWidth, layoutHeight) {
                // Body first (lowest layer)
                contentPlaceables.forEach {
                    it.placeRelative(0, 0)
                }
                // Top bar over content
                topBarPlaceables.forEach { it.placeRelative(0, 0) }
                // Bottom bar pinned to bottom
                bottomBarPlaceables.forEach {
                    it.placeRelative(0, layoutHeight - bottomBarHeight)
                }
                // FAB above bottom bar (respects RTL via explicit offset)
                if (!isFabEmpty) {
                    fabPlaceables.forEach {
                        it.place(fabLeftOffset, layoutHeight - fabOffsetFromBottom)
                    }
                }
                // Snackbar centered, above bottom bar / FAB
                snackbarPlaceables.forEach {
                    val snackbarX =
                        (layoutWidth - snackbarWidth + insetLeft - insetRight) / 2
                    it.placeRelative(snackbarX, layoutHeight - snackbarOffsetFromBottom)
                }
                // Toast overlay on top of everything (highest layer)
                toastPlaceables.forEach { it.placeRelative(0, 0) }
            }
        }
    }
}

// ─── Smart PaddingValues ──────────────────────────────────

private class MutableScaffoldPaddingValues(
    initialPadding: PaddingValues,
) : PaddingValues {
    var paddingHolder by mutableStateOf(initialPadding)

    override fun calculateLeftPadding(layoutDirection: LayoutDirection): Dp = paddingHolder.calculateLeftPadding(layoutDirection)

    override fun calculateTopPadding(): Dp = paddingHolder.calculateTopPadding()

    override fun calculateRightPadding(layoutDirection: LayoutDirection): Dp = paddingHolder.calculateRightPadding(layoutDirection)

    override fun calculateBottomPadding(): Dp = paddingHolder.calculateBottomPadding()
}
